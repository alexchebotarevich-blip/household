import Combine
import Foundation
import UserNotifications

@MainActor
final class ReminderSettingsViewModel: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus
    @Published private(set) var taskDefaultConfiguration: TaskReminderConfiguration
    @Published private(set) var taskEntries: [ReminderPreferences.TaskEntry]
    @Published private(set) var shoppingDefaultConfiguration: ShoppingReminderConfiguration
    @Published private(set) var shoppingEntries: [ReminderPreferences.ShoppingEntry]
    @Published var quietHoursEnabled: Bool
    @Published var quietHoursStart: Date
    @Published var quietHoursEnd: Date

    var leadTimeOptions: [TaskReminderConfiguration.LeadTime] {
        TaskReminderConfiguration.LeadTime.allCases.filter { $0 != .custom }
    }

    private let preferencesStore: ReminderPreferencesStore
    private let authorizationService: NotificationAuthorizationService
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(preferencesStore: ReminderPreferencesStore = .shared,
         authorizationService: NotificationAuthorizationService = .shared,
         calendar: Calendar = .current) {
        self.preferencesStore = preferencesStore
        self.authorizationService = authorizationService
        self.calendar = calendar
        let preferences = preferencesStore.preferences
        self.taskDefaultConfiguration = preferences.taskDefaults
        self.taskEntries = ReminderSettingsViewModel.sortedTasks(preferences.tasks)
        self.shoppingDefaultConfiguration = preferences.shoppingDefaults
        self.shoppingEntries = ReminderSettingsViewModel.sortedShoppingLists(preferences.shoppingLists)
        let quietHours = preferences.quietHours ?? QuietHoursConfiguration()
        self.quietHoursEnabled = quietHours.isEnabled
        self.quietHoursStart = calendar.date(from: quietHours.start) ?? ReminderSettingsViewModel.makeDate(hour: 22, minute: 0, using: calendar)
        self.quietHoursEnd = calendar.date(from: quietHours.end) ?? ReminderSettingsViewModel.makeDate(hour: 7, minute: 0, using: calendar)
        self.authorizationStatus = authorizationService.status

        preferencesStore.$preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] preferences in
                guard let self else { return }
                taskDefaultConfiguration = preferences.taskDefaults
                taskEntries = ReminderSettingsViewModel.sortedTasks(preferences.tasks)
                shoppingDefaultConfiguration = preferences.shoppingDefaults
                shoppingEntries = ReminderSettingsViewModel.sortedShoppingLists(preferences.shoppingLists)
                if let quietHours = preferences.quietHours {
                    quietHoursEnabled = quietHours.isEnabled
                    quietHoursStart = calendar.date(from: quietHours.start) ?? quietHoursStart
                    quietHoursEnd = calendar.date(from: quietHours.end) ?? quietHoursEnd
                } else {
                    quietHoursEnabled = false
                }
            }
            .store(in: &cancellables)

        authorizationService.$status
            .receive(on: DispatchQueue.main)
            .assign(to: \ReminderSettingsViewModel.authorizationStatus, on: self)
            .store(in: &cancellables)
    }

    func requestAuthorization() async {
        let granted = await authorizationService.requestAuthorization()
        if !granted {
            authorizationService.openSettings()
        }
    }

    func openSettings() {
        authorizationService.openSettings()
    }

    func description(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Enabled"
        case .provisional: return "Provisionally enabled"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    func setTaskDefaultLeadTime(_ leadTime: TaskReminderConfiguration.LeadTime) {
        var configuration = taskDefaultConfiguration
        configuration.leadTime = leadTime.rawValue
        configuration.isEnabled = true
        preferencesStore.updateTaskDefaults(configuration)
    }

    func setTaskDefaultsEnabled(_ isEnabled: Bool) {
        var configuration = taskDefaultConfiguration
        configuration.isEnabled = isEnabled
        preferencesStore.updateTaskDefaults(configuration)
    }

    func toggleTask(_ entry: ReminderPreferences.TaskEntry, isEnabled: Bool) {
        var configuration = entry.configuration
        configuration.isEnabled = isEnabled
        preferencesStore.updateTaskConfiguration(id: entry.id, configuration: configuration)
    }

    func updateTask(_ entry: ReminderPreferences.TaskEntry, leadTime: TaskReminderConfiguration.LeadTime) {
        var configuration = entry.configuration
        configuration.leadTime = leadTime.rawValue
        preferencesStore.updateTaskConfiguration(id: entry.id, configuration: configuration)
    }

    func setShoppingDefaultsEnabled(_ isEnabled: Bool) {
        var configuration = shoppingDefaultConfiguration
        configuration.isEnabled = isEnabled
        preferencesStore.updateShoppingDefaults(configuration)
    }

    func setShoppingDefault(time: Date) {
        var configuration = shoppingDefaultConfiguration
        configuration.remindAt = calendar.dateComponents([.hour, .minute], from: time)
        preferencesStore.updateShoppingDefaults(configuration)
    }

    func toggleShopping(_ entry: ReminderPreferences.ShoppingEntry, isEnabled: Bool) {
        var configuration = entry.configuration
        configuration.isEnabled = isEnabled
        preferencesStore.updateShoppingConfiguration(id: entry.id, configuration: configuration)
    }

    func updateShopping(_ entry: ReminderPreferences.ShoppingEntry, time: Date) {
        var configuration = entry.configuration
        configuration.remindAt = calendar.dateComponents([.hour, .minute], from: time)
        preferencesStore.updateShoppingConfiguration(id: entry.id, configuration: configuration)
    }

    func updateQuietHours() {
        guard quietHoursEnabled else {
            preferencesStore.updateQuietHours(QuietHoursConfiguration(isEnabled: false))
            return
        }
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        let configuration = QuietHoursConfiguration(isEnabled: true, start: startComponents, end: endComponents)
        preferencesStore.updateQuietHours(configuration)
    }

    func leadTimeDescription(for configuration: TaskReminderConfiguration) -> String {
        if let component = TaskReminderConfiguration.LeadTime(rawValue: configuration.leadTime) {
            return component.title
        }
        let minutes = Int(configuration.leadTime / 60)
        return "\(minutes) minutes before"
    }

    private static func sortedTasks(_ tasks: [ReminderPreferences.TaskEntry]) -> [ReminderPreferences.TaskEntry] {
        tasks.sorted { lhs, rhs in
            if lhs.configuration.isEnabled == rhs.configuration.isEnabled {
                return lhs.dueDate < rhs.dueDate
            }
            return lhs.configuration.isEnabled && !rhs.configuration.isEnabled
        }
    }

    private static func sortedShoppingLists(_ lists: [ReminderPreferences.ShoppingEntry]) -> [ReminderPreferences.ShoppingEntry] {
        lists.sorted { lhs, rhs in
            switch (lhs.configuration.isEnabled, rhs.configuration.isEnabled) {
            case (true, false): return true
            case (false, true): return false
            default: return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private static func makeDate(hour: Int, minute: Int, using calendar: Calendar) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
