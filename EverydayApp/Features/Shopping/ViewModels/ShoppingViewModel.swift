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
    private var cancellables = Set<AnyCancellable>()
    private var recentlyDeletedItem: ShoppingItem?
    private var undoTimer: AnyCancellable?

    init(
        repository: ShoppingListRepository = OfflineFirstShoppingRepository(),
        user: ShoppingUser = .current
    ) {
        self.repository = repository
        self.user = user
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

    func togglePurchased(for item: ShoppingItem) {
        if item.status == .pending {
            _ = repository.markPurchased(id: item.id, by: user)
        } else if item.status == .purchased {
            _ = repository.markPending(id: item.id)
        }
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
