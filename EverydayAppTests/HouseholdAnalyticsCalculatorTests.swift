import XCTest
@testable import EverydayApp

final class HouseholdAnalyticsCalculatorTests: XCTestCase {
    func testSummaryCalculationsProduceExpectedMetrics() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2024, month: 5, day: 12, hour: 12))!

        let task1 = TaskItem(
            title: "Clean kitchen",
            dueDate: now,
            isCompleted: true,
            assignedTo: "Alex",
            completedBy: "Alex",
            completedAt: calendar.date(byAdding: .day, value: -1, to: now),
            type: .chore
        )

        let task2 = TaskItem(
            title: "Pick up order",
            dueDate: calendar.date(byAdding: .day, value: -2, to: now)!,
            isCompleted: true,
            assignedTo: "Jamie",
            completedBy: "Jamie",
            completedAt: calendar.date(byAdding: .day, value: -1, to: now),
            type: .errand
        )

        let task3 = TaskItem(
            title: "Call plumber",
            dueDate: calendar.date(byAdding: .day, value: -10, to: now)!,
            isCompleted: true,
            assignedTo: "Alex",
            completedBy: "Alex",
            completedAt: calendar.date(byAdding: .day, value: -10, to: now),
            type: .maintenance
        )

        var pendingTask = TaskItem(
            title: "Decorate patio",
            dueDate: calendar.date(byAdding: .day, value: -1, to: now)!,
            isCompleted: false,
            assignedTo: "Taylor",
            type: .celebration
        )
        pendingTask.completedAt = nil

        let tasks = [task1, task2, task3, pendingTask]

        let recentPurchase = ShoppingActivityLogEntry(
            itemID: UUID(),
            itemName: "Milk",
            quantity: 1,
            category: "Dairy",
            actorName: "Jamie",
            action: .purchased,
            timestamp: calendar.date(byAdding: .day, value: -2, to: now)!
        )

        let olderPurchase = ShoppingActivityLogEntry(
            itemID: UUID(),
            itemName: "Detergent",
            quantity: 1,
            category: "Household",
            actorName: "Alex",
            action: .purchased,
            timestamp: calendar.date(byAdding: .day, value: -10, to: now)!
        )

        let summary = HouseholdAnalyticsCalculator.makeSummary(
            tasks: tasks,
            activities: [recentPurchase, olderPurchase],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(summary.weeklyCompletedCount, 2)
        XCTAssertEqual(summary.monthlyCompletedCount, 3)
        XCTAssertEqual(summary.purchasesThisWeek, 1)
        XCTAssertEqual(summary.currentStreak, 1)
        XCTAssertEqual(summary.longestStreak, 1)

        XCTAssertEqual(summary.weeklyOnTimeRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.monthlyCompletionRate, 0.75, accuracy: 0.0001)
        XCTAssertEqual(summary.punctualityRate, 2.0 / 3.0, accuracy: 0.0001)

        XCTAssertEqual(summary.leaderboard.first?.memberName, "Alex")
        XCTAssertEqual(summary.leaderboard.first?.completedCount, 2)
        XCTAssertEqual(summary.leaderboard.first?.onTimeRate, 1.0)
    }

    func testHistoryCombinesTaskCompletionsAndPurchases() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2024, month: 5, day: 12, hour: 12))!

        let task = TaskItem(
            title: "Clean kitchen",
            dueDate: now,
            isCompleted: true,
            assignedTo: "Alex",
            completedBy: "Alex",
            completedAt: calendar.date(byAdding: .hour, value: -2, to: now),
            type: .chore
        )

        let purchase = ShoppingActivityLogEntry(
            itemID: UUID(),
            itemName: "Milk",
            quantity: 1,
            category: "Dairy",
            actorName: "Jamie",
            action: .purchased,
            timestamp: calendar.date(byAdding: .hour, value: -4, to: now)
        )

        let history = HouseholdAnalyticsCalculator.makeHistory(
            tasks: [task],
            activities: [purchase],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.contains(where: { $0.source == .task(.chore) && $0.member == "Alex" }))
        XCTAssertTrue(history.contains(where: { $0.source == .shopping && $0.member == "Jamie" }))
    }
}
