import Combine
import FamilyHubCore
import Foundation

final class FamilyRoleStore: ObservableObject {
    @Published private(set) var roles: [FamilyRole] = []
    @Published var lastError: String?

    let templates: [FamilyRole.Template]

    private let repository: FamilyRoleRepository
    private let shouldBootstrapDefaults: Bool
    private var familyID: String

    init(
        familyID: String = UUID().uuidString,
        repository: FamilyRoleRepository = InMemoryFamilyRoleRepository(),
        templates: [FamilyRole.Template] = FamilyRole.defaultTemplates,
        bootstrapsDefaults: Bool = true
    ) {
        self.familyID = familyID
        self.repository = repository
        self.templates = templates
        self.shouldBootstrapDefaults = bootstrapsDefaults
        bootstrapDefaultsIfNeeded()
        refresh()
    }

    func refresh() {
        do {
            roles = try repository.roles(for: familyID)
        } catch {
            roles = []
            lastError = message(for: error)
        }
    }

    func updateFamily(id: String) {
        familyID = id
        bootstrapDefaultsIfNeeded()
        refresh()
    }

    func addRole(from template: FamilyRole.Template, customTitle: String? = nil, makeDefault: Bool = false) {
        perform {
            var role = template.makeRole(
                familyID: familyID,
                displayOrder: roles.count,
                isDefault: makeDefault
            )
            if let customTitle, customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                role.title = trimmed
                role.metadata.assignmentLabel = "Assign to \(trimmed.lowercased())"
                role.metadata.analyticsTag = trimmed.lowercased().replacingOccurrences(of: " ", with: "_")
            }
            try repository.create(role)
        }
    }

    func update(role editable: EditableFamilyRole) {
        guard let existing = roles.first(where: { $0.id == editable.id }) else { return }
        perform {
            let updated = editable.applying(to: existing)
            try repository.update(updated)
        }
    }

    func delete(roleID: String) {
        perform {
            try repository.delete(roleID: roleID, familyID: familyID)
        }
    }

    func moveRoles(fromOffsets source: IndexSet, to destination: Int) {
        var reordered = roles
        reordered.move(fromOffsets: source, toOffset: destination)
        let identifiers = reordered.map(\.id)
        perform {
            try repository.reorder(roleIDs: identifiers, in: familyID)
        }
    }

    func setDefault(roleID: String) {
        guard var editable = roles.first(where: { $0.id == roleID }).map(EditableFamilyRole.init(role:)) else { return }
        editable.isDefault = true
        update(role: editable)
    }

    func assignmentLabel(for roleID: String?) -> String? {
        guard let roleID, let role = roles.first(where: { $0.id == roleID }) else { return nil }
        return role.metadata.assignmentLabel
    }

    var defaultRoleID: String? {
        roles.first(where: { $0.isDefault })?.id
    }

    private func bootstrapDefaultsIfNeeded() {
        guard shouldBootstrapDefaults else { return }
        let existing = (try? repository.roles(for: familyID)) ?? []
        guard existing.isEmpty else { return }
        for (index, template) in templates.enumerated() {
            var role = template.makeRole(
                familyID: familyID,
                displayOrder: index,
                isDefault: index == 0
            )
            do {
                try repository.create(role)
            } catch {
                lastError = message(for: error)
            }
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            roles = try repository.roles(for: familyID)
            lastError = nil
        } catch {
            lastError = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        if let repositoryError = error as? RepositoryError {
            switch repositoryError {
            case .alreadyExists:
                return "A role with that title already exists."
            case .notFound:
                return "The selected role could not be found."
            case .underlying(let value):
                return value
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
