import XCTest
@testable import EverydayApp

final class GamificationEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset profile for test user by using a fresh UserDefaults suite
        let suite = UserDefaults(suiteName: "GamificationEngineTests_\(UUID().uuidString)")!
        let store = GamificationStore(userDefaults: suite)
        // Inject a fresh engine instance for isolation
        _engine = GamificationEngine(store: store, calendar: Calendar(identifier: .gregorian))
    }

    private var _engine: GamificationEngine!
    private var engine: GamificationEngine { _engine }

    func testPointCalculationOnTimeAndLate() {
        let calendar = Calendar(identifier: .gregorian)
        let due = calendar.date(from: DateComponents(year: 2024, month: 5, day: 12, hour: 12))!
        let earlyCompletion = calendar.date(byAdding: .hour, value: -2, to: due)!
        let lateCompletion = calendar.date(byAdding: .hour, value: 3, to: due)!

        var task = TaskItem(title: "Test", dueDate: due)
        task.isCompleted = true
        task.completedAt = earlyCompletion
        if let result = engine.processTaskCompletion(task, userID: "test-user") {
            // base 50 + on-time 20 + 2 hours early => 72
            XCTAssertEqual(result.addedPoints, 72)
        } else {
            XCTFail("Expected result for on-time completion")
        }

        task.completedAt = lateCompletion
        if let result2 = engine.processTaskCompletion(task, userID: "test-user") {
            // base 50 - (3h * 2) => 44
            XCTAssertEqual(result2.addedPoints, 44)
        } else {
            XCTFail("Expected result for late completion")
        }

        let profile = engine.profile(for: "test-user")
        XCTAssertEqual(profile.points, 72 + 44)
        XCTAssertEqual(profile.tasksCompleted, 2)
    }

    func testAchievementUnlockingAtThresholdsAndStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let baseDay = calendar.date(from: DateComponents(year: 2024, month: 6, day: 10, hour: 12))!

        // Two early on-time completions to surpass 100 points
        var task1 = TaskItem(title: "t1", dueDate: baseDay)
        task1.isCompleted = true
        task1.completedAt = calendar.date(byAdding: .hour, value: -10, to: baseDay) // 50 + 20 + 10 = 80
        _ = engine.processTaskCompletion(task1, userID: "u1")

        var task2 = TaskItem(title: "t2", dueDate: baseDay)
        task2.isCompleted = true
        task2.completedAt = calendar.date(byAdding: .hour, value: -5, to: baseDay) // 50 + 20 + 5 = 75
        _ = engine.processTaskCompletion(task2, userID: "u1")

        var profile = engine.profile(for: "u1")
        XCTAssertGreaterThanOrEqual(profile.points, 155)
        XCTAssertTrue(profile.achievements.contains(where: { $0.key == "POINTS_BRONZE" }))
        XCTAssertTrue(profile.achievements.contains(where: { $0.key == "FIRST_TASK" }))

        // Complete on 3 consecutive days to unlock streak 3
        var d1 = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 10))!
        var d2 = calendar.date(byAdding: .day, value: 1, to: d1)!
        var d3 = calendar.date(byAdding: .day, value: 1, to: d2)!

        var sTask1 = TaskItem(title: "s1", dueDate: d1)
        sTask1.isCompleted = true
        sTask1.completedAt = d1
        _ = engine.processTaskCompletion(sTask1, userID: "streak-user")

        var sTask2 = TaskItem(title: "s2", dueDate: d2)
        sTask2.isCompleted = true
        sTask2.completedAt = d2
        _ = engine.processTaskCompletion(sTask2, userID: "streak-user")

        var sTask3 = TaskItem(title: "s3", dueDate: d3)
        sTask3.isCompleted = true
        sTask3.completedAt = d3
        _ = engine.processTaskCompletion(sTask3, userID: "streak-user")

        profile = engine.profile(for: "streak-user")
        XCTAssertGreaterThanOrEqual(profile.streak, 3)
        XCTAssertTrue(profile.achievements.contains(where: { $0.key == "STREAK_3" }))

        // Ensure achievements are not duplicated
        let priorCount = profile.achievements.filter { $0.key == "STREAK_3" }.count
        _ = engine.processTaskCompletion(sTask3, userID: "streak-user")
        let updated = engine.profile(for: "streak-user")
        let afterCount = updated.achievements.filter { $0.key == "STREAK_3" }.count
        XCTAssertEqual(priorCount, afterCount)
    }
}
