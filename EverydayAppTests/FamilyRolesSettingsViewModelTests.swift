import XCTest
import FamilyHubCore
@testable import EverydayApp

final class FamilyRolesSettingsViewModelTests: XCTestCase {
    private var store: FamilyRoleStore!
    private var viewModel: FamilyRolesSettingsViewModel!

    override func setUp() {
        super.setUp()
        store = makeStore()
        viewModel = FamilyRolesSettingsViewModel(store: store)
        waitForUpdates()
    }

    override func tearDown() {
        viewModel = nil
        store = nil
        super.tearDown()
    }

    func testAddRoleFromTemplateAppendsRole() {
        let newTemplate = FamilyRole.Template(
            title: "Coach",
            description: "Guides routines and practice",
            permissions: [.manageTasks],
            metadata: .init(
                assignmentLabel: "Assign to coach",
                analyticsTag: "coach",
                iconName: "sportscourt"
            )
        )

        viewModel.addRole(from: newTemplate)
        waitForUpdates()

        XCTAssertTrue(viewModel.roles.contains(where: { $0.title == "Coach" }))
    }

    func testDeleteRoleRemovesEntry() {
        XCTAssertGreaterThanOrEqual(viewModel.roles.count, 1)
        let initialCount = viewModel.roles.count
        if let firstRole = viewModel.roles.first {
            viewModel.delete(at: IndexSet(integer: 0))
            waitForUpdates()
            XCTAssertEqual(viewModel.roles.count, initialCount - 1)
            XCTAssertFalse(viewModel.roles.contains(where: { $0.id == firstRole.id }))
        }
    }

    func testSetDefaultPromotesRole() {
        let template = FamilyRole.Template(
            title: "Grandparent",
            description: "Helps with celebrations",
            permissions: [.manageFamily],
            metadata: .init(
                assignmentLabel: "Assign to grandparent",
                analyticsTag: "grandparent",
                iconName: "person.2.square.stack"
            )
        )

        viewModel.addRole(from: template)
        waitForUpdates()
        guard let target = viewModel.roles.first(where: { $0.title == "Grandparent" }) else {
            return XCTFail("Expected role to be created")
        }

        viewModel.setDefault(roleID: target.id)
        waitForUpdates()

        XCTAssertEqual(store.defaultRoleID, target.id)
        XCTAssertTrue(viewModel.roles.first(where: { $0.id == target.id })?.isDefault ?? false)
    }

    func testMoveUpdatesDisplayOrder() {
        let additionalTemplate = FamilyRole.Template(
            title: "Caretaker",
            description: "Supports routines",
            permissions: [.manageTasks, .manageShopping],
            metadata: .init(
                assignmentLabel: "Assign to caretaker",
                analyticsTag: "caretaker",
                iconName: "stethoscope"
            )
        )
        viewModel.addRole(from: additionalTemplate)
        waitForUpdates()

        guard viewModel.roles.count >= 2 else {
            return XCTFail("Expected at least two roles")
        }

        viewModel.move(from: IndexSet(integer: viewModel.roles.count - 1), to: 0)
        waitForUpdates()

        let reorderedIDs = store.roles.map(\.id)
        XCTAssertEqual(reorderedIDs.first, viewModel.roles.first?.id)
    }

    // MARK: - Helpers

    private func makeStore() -> FamilyRoleStore {
        let repository = InMemoryFamilyRoleRepository()
        let familyID = "test_family"
        let baseTemplate = FamilyRole.Template(
            title: "Partner",
            description: "Primary collaborator",
            permissions: FamilyRole.Permission.allCases,
            metadata: .init(
                assignmentLabel: "Assign to partner",
                analyticsTag: "partner",
                iconName: "heart.fill"
            )
        )
        let role = baseTemplate.makeRole(
            familyID: familyID,
            displayOrder: 0,
            isDefault: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try? repository.create(role)
        return FamilyRoleStore(
            familyID: familyID,
            repository: repository,
            templates: FamilyRole.defaultTemplates,
            bootstrapsDefaults: false
        )
    }

    private func waitForUpdates(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "Awaiting main queue updates")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }
}
