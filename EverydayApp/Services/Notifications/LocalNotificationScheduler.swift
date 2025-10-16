import Foundation
import UserNotifications

protocol ReminderScheduling {
    func scheduleTaskReminder(for task: TaskItem)
    func cancelTaskReminder(for taskID: UUID)
    func scheduleShoppingReminder(listID: String, title: String, pendingItemCount: Int)
    func cancelShoppingReminder(for listID: String)
}

protocol UserNotificationCenterManaging {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenterManaging {}

final class LocalNotificationScheduler: ReminderScheduling {
    static let shared = LocalNotificationScheduler()

    private let center: UserNotificationCenterManaging
    private let preferencesStore: ReminderPreferencesStore
    private let calendar: Calendar

    init(center: UserNotificationCenterManaging = UNUserNotificationCenter.current(),
         preferencesStore: ReminderPreferencesStore = .shared,
         calendar: Calendar = .current) {
        self.center = center
        self.preferencesStore = preferencesStore
        self.calendar = calendar
    }

    func scheduleTaskReminder(for task: TaskItem) {
        preferencesStore.register(task: task)
        let configuration = preferencesStore.taskConfiguration(for: task.id)
        guard configuration.isEnabled else {
            cancelTaskReminder(for: task.id)
            return
        }

        let triggerDate = task.dueDate.addingTimeInterval(-configuration.leadTime)
        let adjustedDate = adjusted(date: triggerDate)
        guard adjustedDate.timeIntervalSinceNow > 60 else {
            // Skip scheduling notifications that would fire immediately or in the past.
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = "Due at \(task.dueDate.formatted(date: .abbreviated, time: .shortened))"
        content.sound = .default
        content.userInfo = [
            NotificationPayload.Keys.target: NotificationPayload.Target.task.rawValue,
            NotificationPayload.Keys.identifier: task.id.uuidString
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: adjustedDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(forTaskID: task.id), content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                #if DEBUG
                print("⚠️ Failed to schedule task reminder: \(error)")
                #endif
            }
        }
    }

    func cancelTaskReminder(for taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(forTaskID: taskID)])
    }

    func scheduleShoppingReminder(listID: String, title: String, pendingItemCount: Int) {
        guard pendingItemCount > 0 else {
            cancelShoppingReminder(for: listID)
            return
        }

        preferencesStore.registerShoppingList(id: listID, title: title)
        let configuration = preferencesStore.shoppingConfiguration(for: listID)
        guard configuration.isEnabled else {
            cancelShoppingReminder(for: listID)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Shopping Reminder"
        content.body = "You have \(pendingItemCount) pending item\(pendingItemCount == 1 ? "" : "s") in \(title)."
        content.sound = .default
        content.userInfo = [
            NotificationPayload.Keys.target: NotificationPayload.Target.shopping.rawValue,
            NotificationPayload.Keys.identifier: listID
        ]

        let identifiers = shoppingIdentifiers(for: listID, weekdays: configuration.weekdays)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        if configuration.weekdays.isEmpty {
            scheduleShoppingRequest(identifier: identifiers.first ?? identifier(forListID: listID),
                                    content: content,
                                    baseComponents: configuration.remindAt,
                                    weekday: nil,
                                    repeats: true)
        } else {
            for weekday in configuration.weekdays {
                let identifier = identifier(forListID: listID, weekday: weekday)
                scheduleShoppingRequest(identifier: identifier,
                                        content: content,
                                        baseComponents: configuration.remindAt,
                                        weekday: weekday,
                                        repeats: true)
            }
        }
    }

    func cancelShoppingReminder(for listID: String) {
        let identifiers = shoppingIdentifiers(for: listID, weekdays: nil)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Helpers

    private func scheduleShoppingRequest(identifier: String,
                                         content: UNNotificationContent,
                                         baseComponents: DateComponents,
                                         weekday: Int?,
                                         repeats: Bool) {
        var components = baseComponents
        components.second = 0
        if let weekday {
            components.weekday = weekday
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                #if DEBUG
                print("⚠️ Failed to schedule shopping reminder: \(error)")
                #endif
            }
        }
    }

    private func adjusted(date: Date) -> Date {
        guard let quietHours = preferencesStore.currentQuietHours() else { return date }
        return quietHours.nextAvailableDate(after: date, calendar: calendar)
    }

    private func identifier(forTaskID id: UUID) -> String {
        "task-reminder-\(id.uuidString)"
    }

    private func identifier(forListID id: String, weekday: Int? = nil) -> String {
        if let weekday {
            return "shopping-reminder-\(id)-weekday-\(weekday)"
        }
        return "shopping-reminder-\(id)"
    }

    private func shoppingIdentifiers(for listID: String, weekdays: Set<Int>?) -> [String] {
        if let weekdays, !weekdays.isEmpty {
            return weekdays.map { identifier(forListID: listID, weekday: $0) }
        }
        return [identifier(forListID: listID)]
    }
}
