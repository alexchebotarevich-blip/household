import XCTest
import FamilyHubCore
import SwiftUI
@testable import EverydayApp

final class FamilyRolesSettingsSnapshotTests: XCTestCase {
    func testSettingsViewSnapshotDescriptionMatchesBaseline() {
        let repository = InMemoryFamilyRoleRepository()
        let familyID = "snapshot_family"
        let templates = FamilyRole.defaultTemplates
        let initialRoles = templates.prefix(2).enumerated().map { index, template in
            template.makeRole(
                familyID: familyID,
                displayOrder: index,
                isDefault: index == 0,
                createdAt: Date(timeIntervalSince1970: 1_700_100_000 + Double(index))
            )
        }
        initialRoles.forEach { try? repository.create($0) }

        let store = FamilyRoleStore(
            familyID: familyID,
            repository: repository,
            templates: templates,
            bootstrapsDefaults: false
        )
        let viewModel = FamilyRolesSettingsViewModel(store: store)
        let view = FamilyRolesSettingsView(viewModel: viewModel)

        let snapshot = snapshotDescription(for: view)
        let expected = "Roles:\n0: Partner | default | Assign to partner\n1: Child | member | Assign to child\nTemplates: Partner, Child, Grandparent, Caregiver, Pet"
        XCTAssertEqual(snapshot, expected)
    }

    private func snapshotDescription(for view: FamilyRolesSettingsView) -> String {
        let roleSummary = view.viewModel.roles
            .sorted(by: { $0.displayOrder < $1.displayOrder })
            .enumerated()
            .map { index, role in
                let status = role.isDefault ? "default" : "member"
                return "\(index): \(role.title) | \(status) | \(role.assignmentLabel)"
            }
            .joined(separator: "\n")

        let templatesSummary = view.viewModel.templates.map(\.title).joined(separator: ", ")
        return "Roles:\n\(roleSummary)\nTemplates: \(templatesSummary)"
    }
}
