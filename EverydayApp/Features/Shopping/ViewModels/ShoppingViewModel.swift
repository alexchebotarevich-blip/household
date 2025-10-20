import Foundation
import Combine

final class ShoppingViewModel: ObservableObject {
    @Published private(set) var pendingItems: [ShoppingItem] = []
    @Published private(set) var purchasedItems: [ShoppingItem] = []
    @Published private(set) var purchaseHistory: [ShoppingActivityLogEntry] = []
    @Published private(set) var availableCategories: [String] = ShoppingViewModel.defaultCategories
    @Published var undoPrompt: UndoPrompt?

    private let repository: ShoppingListRepository
    private let user: ShoppingUser
    private let reminderScheduler: ReminderScheduling
    private let preferencesStore: ReminderPreferencesStore
    private var cancellables = Set<AnyCancellable>()
    private var recentlyDeletedItem: ShoppingItem?
    private var undoTimer: AnyCancellable?

    init(
        repository: ShoppingListRepository = OfflineFirstShoppingRepository.shared,
        user: ShoppingUser = .current,
        reminderScheduler: ReminderScheduling = LocalNotificationScheduler.shared,
        preferencesStore: ReminderPreferencesStore = .shared
    ) {
        self.repository = repository
        self.user = user
        self.reminderScheduler = reminderScheduler
        self.preferencesStore = preferencesStore
        bind()
    }

    func makeNewFormState() -> ShoppingItemFormState {
        ShoppingItemFormState(category: availableCategories.first ?? "General")
    }

    func formState(for item: ShoppingItem) -> ShoppingItemFormState {
        ShoppingItemFormState(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            category: item.category,
            assignee: item.assignee ?? "",
            notes: item.notes ?? ""
        )
    }

    func save(form: ShoppingItemFormState) {
        guard form.isValid else { return }
        let trimmedNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAssignee = form.assignee.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        if let id = form.id, var existing = repository.item(with: id) {
            existing.name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.quantity = form.quantity
            existing.category = form.category
            existing.assignee = trimmedAssignee.isEmpty ? nil : trimmedAssignee
            existing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existing.updatedAt = now
            repository.update(existing)
        } else {
            let newItem = ShoppingItem(
                name: form.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: form.quantity,
                category: form.category,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                assignee: trimmedAssignee.isEmpty ? nil : trimmedAssignee,
                status: .pending,
                createdBy: user.displayName,
                createdAt: now
            )
            repository.add(newItem)
        }
    }

    @discardableResult
    func togglePurchased(for item: ShoppingItem) -> ShoppingItem? {
        if item.status == .pending {
            return repository.markPurchased(id: item.id, by: user)
        } else if item.status == .purchased {
            return repository.markPending(id: item.id)
        }
        return nil
    }

    func delete(_ item: ShoppingItem) {
        recentlyDeletedItem = repository.delete(id: item.id, actor: user)
        guard recentlyDeletedItem != nil else { return }
        undoPrompt = UndoPrompt(
            title: "Item removed",
            message: "\(item.name) was removed from your list.",
            onUndo: { [weak self] in self?.undoLastDeletion() }
        )
        scheduleUndoCleanup()
    }

    func undoLastDeletion() {
        undoTimer?.cancel()
        undoTimer = nil
        guard let removed = recentlyDeletedItem else {
            undoPrompt = nil
            return
        }
        repository.restore(removed)
        recentlyDeletedItem = nil
        undoPrompt = nil
    }

    private func bind() {
        repository
            .updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.apply(items)
            }
            .store(in: &cancellables)

        repository
            .activityUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.purchaseHistory = Array(entries.prefix(10))
            }
            .store(in: &cancellables)
    }

    private func apply(_ items: [ShoppingItem]) {
        let pending = items.filter { $0.status == .pending }
            .sorted(by: ShoppingViewModel.sortForPending)
        let purchased = items.filter { $0.status == .purchased }
            .sorted(by: ShoppingViewModel.sortForPurchased)

        pendingItems = pending
        purchasedItems = purchased

        var categories = Set(ShoppingViewModel.defaultCategories)
        items.map { $0.category }.forEach { categories.insert($0) }
        availableCategories = categories.sorted()
        scheduleReminders(forPendingItems: pending)
    }

    private func scheduleReminders(forPendingItems pending: [ShoppingItem]) {
        let grouped = Dictionary(grouping: pending) { $0.category }
        let activeListIDs = grouped.keys.map { slug(for: $0) }

        for (category, items) in grouped {
            let slug = slug(for: category)
            preferencesStore.registerShoppingList(id: slug, title: category)
            reminderScheduler.scheduleShoppingReminder(listID: slug, title: category, pendingItemCount: items.count)
        }

        for category in availableCategories where !grouped.keys.contains(category) {
            let slug = slug(for: category)
            preferencesStore.registerShoppingList(id: slug, title: category)
            reminderScheduler.cancelShoppingReminder(for: slug)
        }

        let registeredIDs = preferencesStore.preferences.shoppingLists.map(\.id)
        for registeredID in registeredIDs where !activeListIDs.contains(registeredID) {
            reminderScheduler.cancelShoppingReminder(for: registeredID)
        }
    }

    private func slug(for category: String) -> String {
        category
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func scheduleUndoCleanup() {
        undoTimer?.cancel()
        undoTimer = AnyCancellable(
            DispatchWorkItemScheduler.schedule(after: .now() + 6) { [weak self] in
                guard let self else { return }
                self.recentlyDeletedItem = nil
                self.undoPrompt = nil
            }
        )
    }
}

extension ShoppingViewModel {
    static let defaultCategories: [String] = [
        "Produce",
        "Bakery",
        "Pantry",
        "Dairy",
        "Frozen",
        "Household",
        "Other"
    ]

    static func sortForPending(lhs: ShoppingItem, rhs: ShoppingItem) -> Bool {
        lhs.createdAt > rhs.createdAt
    }

    static func sortForPurchased(lhs: ShoppingItem, rhs: ShoppingItem) -> Bool {
        let lhsDate = lhs.purchasedAt ?? lhs.createdAt
        let rhsDate = rhs.purchasedAt ?? rhs.createdAt
        return lhsDate > rhsDate
    }

    struct UndoPrompt: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let onUndo: () -> Void
    }
}

private struct DispatchWorkItemScheduler {
    static func schedule(after deadline: DispatchTime, operation: @escaping () -> Void) -> AnyCancellable {
        let workItem = DispatchWorkItem(block: operation)
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
        return AnyCancellable {
            workItem.cancel()
        }
    }
}
