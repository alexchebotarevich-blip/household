import FamilyHubCore
import SwiftUI

struct FamilyRolesSettingsView: View {
    @ObservedObject var viewModel: FamilyRolesSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    init(store: FamilyRoleStore) {
        self._viewModel = ObservedObject(wrappedValue: FamilyRolesSettingsViewModel(store: store))
    }

    init(viewModel: FamilyRolesSettingsViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                TextField("Search roles", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.words)
            }

            Section(header: Text("Family roles")) {
                ForEach($viewModel.roles) { $role in
                    FamilyRoleRow(
                        role: $role,
                        onSave: { viewModel.update(role: role) },
                        onSetDefault: { viewModel.setDefault(roleID: role.id) }
                    )
                }
                .onDelete(perform: viewModel.delete)
                .onMove(perform: viewModel.move)

                if let message = viewModel.infoMessage {
                    Text(message)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.colors.primary)
                }
                if let error = viewModel.lastError {
                    Text(error)
                        .font(theme.typography.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Templates")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.small) {
                        ForEach(viewModel.templates, id: \.id) { template in
                            Button {
                                viewModel.addRole(from: template)
                            } label: {
                                VStack(spacing: theme.spacing.xSmall) {
                                    if let iconName = template.metadata.iconName {
                                        Image(systemName: iconName)
                                            .font(.system(size: 24))
                                            .foregroundStyle(theme.colors.primary)
                                    }
                                    Text(template.title)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.primary)
                                        .padding(.horizontal, theme.spacing.xSmall)
                                }
                                .padding(theme.spacing.small)
                                .background(theme.colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, theme.spacing.xSmall)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Family roles")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct FamilyRoleRow: View {
    @Binding var role: EditableFamilyRole
    let onSave: () -> Void
    let onSetDefault: () -> Void
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Role title", text: $role.title)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                Button {
                    onSetDefault()
                } label: {
                    Image(systemName: role.isDefault ? "star.fill" : "star")
                        .foregroundStyle(role.isDefault ? .yellow : .secondary)
                }
                .accessibilityLabel(role.isDefault ? "Default role" : "Make default role")
            }

            TextField("Assignment label", text: $role.assignmentLabel)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)

            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Description", text: $role.description, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Analytics tag", text: $role.analyticsTag)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Icon", text: Binding(
                        get: { role.iconName ?? "" },
                        set: { newValue in
                            role.iconName = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                        }
                    ))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }
            } label: {
                Text("More options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSave) {
                Label("Save changes", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}

#if DEBUG
struct FamilyRolesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FamilyRolesSettingsView(store: FamilyRoleStore())
        }
        .environment(\.appTheme, .default)
    }
}
#endif
