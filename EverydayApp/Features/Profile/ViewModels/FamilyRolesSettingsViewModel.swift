import Combine
import FamilyHubCore
import Foundation

final class FamilyRolesSettingsViewModel: ObservableObject {
    @Published var roles: [EditableFamilyRole] = []
    @Published var lastError: String?
    @Published var infoMessage: String?
    @Published var searchQuery: String = ""

    var templates: [FamilyRole.Template] { store.templates }

    private let store: FamilyRoleStore
    private var cancellables = Set<AnyCancellable>()

    init(store: FamilyRoleStore) {
        self.store = store
        store.$roles
            .map { $0.map(EditableFamilyRole.init(role:)) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] roles in
                self?.roles = roles
            }
            .store(in: &cancellables)

        store.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let message else { return }
                self?.infoMessage = nil
                self?.lastError = message
            }
            .store(in: &cancellables)
    }

    func addRole(from template: FamilyRole.Template, customTitle: String? = nil) {
        store.addRole(from: template, customTitle: customTitle)
        infoMessage = "Added \(customTitle?.isEmpty == false ? customTitle! : template.title)"
        lastError = nil
    }

    func update(role: EditableFamilyRole) {
        store.update(role: role)
        if lastError == nil {
            infoMessage = "Saved changes to \(role.title)"
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            guard roles.indices.contains(index) else { continue }
            let identifier = roles[index].id
            store.delete(roleID: identifier)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        store.moveRoles(fromOffsets: source, to: destination)
    }

    func setDefault(roleID: String) {
        store.setDefault(roleID: roleID)
    }

    func filteredRoles() -> [EditableFamilyRole] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return roles.sorted(by: { $0.displayOrder < $1.displayOrder }) }
        return roles.filter { role in
            role.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || role.description.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        .sorted(by: { $0.displayOrder < $1.displayOrder })
    }
}
