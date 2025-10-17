import XCTest
import UserNotifications
@testable import EverydayApp

final class ReminderSchedulingTests: XCTestCase {
    private var mockCenter: MockNotificationCenter!
    private var preferencesStore: ReminderPreferencesStore!
    private var scheduler: LocalNotificationScheduler!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "ReminderSchedulingTests")
        userDefaults.removePersistentDomain(forName: "ReminderSchedulingTests")
        preferencesStore = ReminderPreferencesStore(userDefaults: userDefaults)
        mockCenter = MockNotificationCenter()
        scheduler = LocalNotificationScheduler(center: mockCenter, preferencesStore: preferencesStore, calendar: Calendar(identifier: .gregorian))
    }

    override func tearDown() {
        scheduler = nil
        mockCenter = nil
        preferencesStore = nil
        if let userDefaults {
            userDefaults.removePersistentDomain(forName: "ReminderSchedulingTests")
        }
        userDefaults = nil
        super.tearDown()
    }

    func testSchedulesTaskReminderWithLeadTime() {
        let calendar = Calendar(identifier: .gregorian)
        let dueDate = calendar.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14_400)
        let task = TaskItem(title: "Test Task", dueDate: dueDate)

        scheduler.scheduleTaskReminder(for: task)

        XCTAssertEqual(mockCenter.requests.count, 1)
        let request = mockCenter.requests.first!
        XCTAssertEqual(request.identifier, "task-reminder-\(task.id.uuidString)")
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return XCTFail("Expected calendar trigger")
        }
        let expected = dueDate.addingTimeInterval(-3_600)
        let nextTrigger = trigger.nextTriggerDate()
        XCTAssertNotNil(nextTrigger)
        XCTAssertEqual(nextTrigger!.timeIntervalSince(expected), 0, accuracy: 2)
    }

    func testTaskReminderRespectsQuietHours() {
        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = calendar.startOfDay(for: Date().addingTimeInterval(86_400))
        let dueDate = calendar.date(byAdding: DateComponents(hour: 7, minute: 30), to: tomorrow) ?? Date().addingTimeInterval(108_000)
        preferencesStore.updateQuietHours(QuietHoursConfiguration(isEnabled: true,
                                                                  start: DateComponents(hour: 21, minute: 0),
                                                                  end: DateComponents(hour: 7, minute: 0)))
        let task = TaskItem(title: "Morning Prep", dueDate: dueDate)

        scheduler.scheduleTaskReminder(for: task)

        let request = mockCenter.requests.first
        XCTAssertNotNil(request)
        guard let trigger = request?.trigger as? UNCalendarNotificationTrigger else {
            return XCTFail("Expected calendar trigger")
        }
        let nextTrigger = trigger.nextTriggerDate()
        XCTAssertNotNil(nextTrigger)
        let expected = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dueDate) ?? dueDate
        XCTAssertEqual(nextTrigger!.timeIntervalSince(expected), 0, accuracy: 2)
    }

    func testShoppingReminderSchedulesAndCancels() {
        preferencesStore.updateShoppingDefaults(ShoppingReminderConfiguration(isEnabled: true,
                                                                               remindAt: DateComponents(hour: 18, minute: 0)))

        scheduler.scheduleShoppingReminder(listID: "groceries", title: "Groceries", pendingItemCount: 3)
        XCTAssertEqual(mockCenter.requests.count, 1)
        XCTAssertEqual(mockCenter.requests.first?.identifier, "shopping-reminder-groceries")

        scheduler.scheduleShoppingReminder(listID: "groceries", title: "Groceries", pendingItemCount: 0)
        XCTAssertTrue(mockCenter.requests.isEmpty)
    }
}

final class MockNotificationCenter: UserNotificationCenterManaging {
    private(set) var requests: [UNNotificationRequest] = []

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        if let index = requests.firstIndex(where: { $0.identifier == request.identifier }) {
            requests[index] = request
        } else {
            requests.append(request)
        }
        completionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        requests.removeAll { identifiers.contains($0.identifier) }
    }
}
