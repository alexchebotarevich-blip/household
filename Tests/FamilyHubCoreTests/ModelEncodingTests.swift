import XCTest
@testable import FamilyHubCore

final class ModelEncodingTests: XCTestCase {
    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testAppUserRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_000_000)
        let user = AppUser(
            id: "user_123",
            email: "carol@example.com",
            displayName: "Carol Example",
            photoURL: URL(string: "https://example.com/avatar.png"),
            familyID: "family_42",
            roleIDs: ["role_admin", "role_viewer"],
            deviceTokens: [.init(token: "token-1", lastUpdated: timestamp)],
            isActive: true,
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(120)
        )

        let decoded = try roundTrip(user)
        XCTAssertEqual(decoded, user)
    }

    func testFamilyRoleRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_100_000)
        let role = FamilyRole(
            id: "role_manager",
            familyID: "family_42",
            title: "Partner",
            description: "Full access to family management features",
            permissions: FamilyRole.Permission.allCases,
            displayOrder: 0,
            isDefault: true,
            metadata: .init(
                assignmentLabel: "Assign to partner",
                analyticsTag: "partner",
                iconName: "heart.fill"
            ),
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(200)
        )

        let decoded = try roundTrip(role)
        XCTAssertEqual(decoded, role)
    }

    func testFamilyRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_200_000)
        let members = [Family.Member(userID: "user_123", roleIDs: ["role_admin"], joinedAt: timestamp, invitedBy: "user_321")]
        let family = Family(
            id: "family_42",
            name: "The Example Family",
            ownerID: "user_123",
            members: members,
            photoURL: URL(string: "https://example.com/family.png"),
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(3600)
        )

        let decoded = try roundTrip(family)
        XCTAssertEqual(decoded, family)
    }

    func testTaskItemRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_300_000)
        let repeatRule = TaskItem.RepeatRule(frequency: .weekly, interval: 1, daysOfWeek: [2, 4])
        let checklist = [TaskItem.ChecklistItem(title: "Gather supplies", isDone: false, assignedTo: "user_123")]
        let task = TaskItem(
            id: "task_1",
            familyID: "family_42",
            name: "Prepare weekly dinner",
            details: "Plan and cook family dinner",
            dueDate: timestamp.addingTimeInterval(86_400),
            status: .inProgress,
            priority: .high,
            assigneeIDs: ["user_123", "user_456"],
            repeatRule: repeatRule,
            checklist: checklist,
            createdBy: "user_123",
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(1_800),
            completedAt: nil
        )

        let decoded = try roundTrip(task)
        XCTAssertEqual(decoded, task)
    }

    func testShoppingItemRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_400_000)
        let item = ShoppingItem(
            id: "item_1",
            familyID: "family_42",
            name: "Oat milk",
            quantity: 2.0,
            unit: "litres",
            notes: "Unsweetened preferred",
            status: .pending,
            createdBy: "user_456",
            assigneeID: "user_123",
            purchasedBy: nil,
            createdAt: timestamp,
            updatedAt: nil,
            purchasedAt: nil
        )

        let decoded = try roundTrip(item)
        XCTAssertEqual(decoded, item)
    }

    func testActivityLogRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_689_500_000)
        let log = ActivityLog(
            id: "log_1",
            familyID: "family_42",
            actorID: "user_123",
            action: .taskCreated,
            targetID: "task_1",
            message: "Carol created a new task",
            metadata: ["taskName": "Prepare weekly dinner"],
            createdAt: timestamp
        )

        let decoded = try roundTrip(log)
        XCTAssertEqual(decoded, log)
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }
}
