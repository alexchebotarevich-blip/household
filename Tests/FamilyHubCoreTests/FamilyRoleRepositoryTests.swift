import XCTest
@testable import FamilyHubCore

final class FamilyRoleRepositoryTests: XCTestCase {
    private var store: InMemoryRepositoryStore!
    private var repository: InMemoryFamilyRoleRepository!
    private var familyID: String!
    private var timestamp: Date!

    override func setUp() {
        super.setUp()
        store = InMemoryRepositoryStore()
        repository = InMemoryFamilyRoleRepository(store: store)
        familyID = UUID().uuidString
        timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    }

    override func tearDown() {
        familyID = nil
        repository = nil
        store = nil
        timestamp = nil
        super.tearDown()
    }

    func testCreateAssignsDisplayOrderAndDefault() throws {
        let partner = makeRole(id: "role_partner", title: "Partner", isDefault: true, displayOrder: 0)
        try repository.create(partner)

        let child = makeRole(id: "role_child", title: "Child", displayOrder: 10)
        try repository.create(child)

        let roles = try repository.roles(for: familyID)
        XCTAssertEqual(roles.count, 2)
        XCTAssertEqual(roles[0].title, "Partner")
        XCTAssertEqual(roles[0].displayOrder, 0)
        XCTAssertTrue(roles[0].isDefault)
        XCTAssertEqual(roles[1].title, "Child")
        XCTAssertEqual(roles[1].displayOrder, 1)
        XCTAssertFalse(roles[1].isDefault)
    }

    func testCreateRejectsDuplicateTitles() throws {
        try repository.create(makeRole(id: "role_partner", title: "Partner"))

        XCTAssertThrowsError(try repository.create(makeRole(id: "role_partner_2", title: "partner"))) { error in
            guard case RepositoryError.alreadyExists = error else {
                return XCTFail("Expected alreadyExists, received: \(error)")
            }
        }
    }

    func testUpdateTrimsMetadataAndMaintainsDefault() throws {
        try repository.create(makeRole(id: "role_partner", title: "Partner", isDefault: true))

        var updated = makeRole(
            id: "role_partner",
            title: "  Partner  ",
            metadata: .init(
                assignmentLabel: "  ",
                analyticsTag: "  Primary ",
                iconName: "  star.fill  "
            ),
            isDefault: true
        )
        updated.updatedAt = timestamp
        try repository.update(updated)

        let roles = try repository.roles(for: familyID)
        XCTAssertEqual(roles.count, 1)
        XCTAssertEqual(roles[0].metadata.assignmentLabel, "Partner")
        XCTAssertEqual(roles[0].metadata.analyticsTag, "primary")
        XCTAssertEqual(roles[0].metadata.iconName, "star.fill")
        XCTAssertTrue(roles[0].isDefault)
    }

    func testDeleteReassignsDefault() throws {
        let defaultRole = makeRole(id: "role_partner", title: "Partner", isDefault: true)
        let backupRole = makeRole(id: "role_grandparent", title: "Grandparent", displayOrder: 1)
        try repository.create(defaultRole)
        try repository.create(backupRole)

        try repository.delete(roleID: "role_partner", familyID: familyID)

        let roles = try repository.roles(for: familyID)
        XCTAssertEqual(roles.count, 1)
        XCTAssertEqual(roles[0].id, "role_grandparent")
        XCTAssertTrue(roles[0].isDefault)
        XCTAssertEqual(roles[0].displayOrder, 0)
    }

    func testDeleteCreatesFallbackWhenLastRoleRemoved() throws {
        try repository.create(makeRole(id: "role_partner", title: "Partner", isDefault: true))

        try repository.delete(roleID: "role_partner", familyID: familyID)

        let roles = try repository.roles(for: familyID)
        XCTAssertEqual(roles.count, 1)
        XCTAssertEqual(roles[0].title, "Member")
        XCTAssertTrue(roles[0].isDefault)
        XCTAssertEqual(roles[0].metadata.assignmentLabel, "Assign to member")
    }

    func testReorderUpdatesDisplayOrder() throws {
        let partner = makeRole(id: "role_partner", title: "Partner", isDefault: true, displayOrder: 0)
        let child = makeRole(id: "role_child", title: "Child", displayOrder: 1)
        let grandparent = makeRole(id: "role_grandparent", title: "Grandparent", displayOrder: 2)
        try repository.create(partner)
        try repository.create(child)
        try repository.create(grandparent)

        try repository.reorder(roleIDs: ["role_grandparent", "role_partner", "role_child"], in: familyID)

        let roles = try repository.roles(for: familyID)
        XCTAssertEqual(roles.map(\.id), ["role_grandparent", "role_partner", "role_child"])
        XCTAssertEqual(roles.map(\.displayOrder), [0, 1, 2])
        XCTAssertTrue(roles[1].isDefault)
    }

    // MARK: - Helpers

    private func makeRole(
        id: String,
        title: String,
        description: String? = nil,
        metadata: FamilyRole.Metadata? = nil,
        isDefault: Bool = false,
        displayOrder: Int = 0
    ) -> FamilyRole {
        let metadata = metadata ?? FamilyRole.Metadata(
            assignmentLabel: title,
            analyticsTag: title.lowercased(),
            iconName: nil
        )
        return FamilyRole(
            id: id,
            familyID: familyID,
            title: title,
            description: description,
            permissions: [.manageTasks],
            displayOrder: displayOrder,
            isDefault: isDefault,
            metadata: metadata,
            createdAt: timestamp,
            updatedAt: nil
        )
    }
}
