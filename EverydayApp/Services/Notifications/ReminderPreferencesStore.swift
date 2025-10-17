import Foundation
import Combine

final class ReminderPreferencesStore: ObservableObject {
    static let shared = ReminderPreferencesStore()

    @Published private(set) var preferences: ReminderPreferences

    private let userDefaults: UserDefaults
    private let storageKey = "com.everydayapp.reminderPreferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? decoder.decode(ReminderPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }

        $preferences
            .dropFirst()
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] preferences in
                self?.persist(preferences)
            }
            .store(in: &cancellables)
    }

    func taskConfiguration(for id: UUID) -> TaskReminderConfiguration {
        preferences.taskEntry(with: id)?.configuration ?? preferences.taskDefaults
    }

    func shoppingConfiguration(for id: String) -> ShoppingReminderConfiguration {
        preferences.shoppingEntry(with: id)?.configuration ?? preferences.shoppingDefaults
    }

    func register(task: TaskItem) {
        preferences.upsertTask(
            ReminderPreferences.TaskEntry(id: task.id, title: task.title, dueDate: task.dueDate,
                                            configuration: taskConfiguration(for: task.id))
        )
    }

    func updateTaskConfiguration(id: UUID, configuration: TaskReminderConfiguration) {
        preferences.updateTask(id: id) { entry in
            entry.configuration = configuration
        }
    }

    func updateTaskTitle(id: UUID, title: String, dueDate: Date) {
        preferences.updateTask(id: id) { entry in
            entry.title = title
            entry.dueDate = dueDate
        }
    }

    func registerShoppingList(id: String, title: String) {
        preferences.upsertShoppingList(
            ReminderPreferences.ShoppingEntry(id: id, title: title,
                                              configuration: shoppingConfiguration(for: id))
        )
    }

    func updateShoppingConfiguration(id: String, configuration: ShoppingReminderConfiguration) {
        preferences.updateShoppingList(id: id) { entry in
            entry.configuration = configuration
        }
    }

    func updateShoppingTitle(id: String, title: String) {
        preferences.updateShoppingList(id: id) { entry in
            entry.title = title
        }
    }

    func updateTaskDefaults(_ configuration: TaskReminderConfiguration) {
        preferences.taskDefaults = configuration
    }

    func updateShoppingDefaults(_ configuration: ShoppingReminderConfiguration) {
        preferences.shoppingDefaults = configuration
    }

    func updateQuietHours(_ configuration: QuietHoursConfiguration?) {
        preferences.quietHours = configuration
    }

    func currentQuietHours() -> QuietHoursConfiguration? {
        preferences.quietHours
    }

    private func persist(_ preferences: ReminderPreferences) {
        do {
            let data = try encoder.encode(preferences)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist reminder preferences: \(error)")
            #endif
        }
    }
}
