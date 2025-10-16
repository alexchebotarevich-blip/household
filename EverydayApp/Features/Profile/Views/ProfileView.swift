import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var roleStore: FamilyRoleStore
    @State private var editedName: String = ""

    init(viewModel: ProfileViewModel = ProfileViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _editedName = State(initialValue: viewModel.profile.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Display name", text: $editedName)
                        .onSubmit(saveName)
                    Text(viewModel.profile.email)
                }

                Section("Household") {
                    ForEach(viewModel.profile.householdMembers) { member in
                        Menu {
                            ForEach(roleStore.roles) { role in
                                Button {
                                    viewModel.assign(roleID: role.id, to: member.id)
                                } label: {
                                    Label(role.title, systemImage: role.metadata.iconName ?? "person")
                                    if member.roleID == role.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            if member.roleID != nil {
                                Button(role: .destructive) {
                                    viewModel.assign(roleID: nil, to: member.id)
                                } label: {
                                    Label("Clear role", systemImage: "xmark.circle")
                                }
                            }
                        } label: {
                            LabeledContent(member.name, value: roleStore.assignmentLabel(for: member.roleID) ?? "Unassigned")
                        }
                    }

                    NavigationLink("Manage roles") {
                        FamilyRolesSettingsView(store: roleStore)
                    }
                }

                Section("Preferences") {
                    NavigationLink("Reminder settings") {
                        ReminderSettingsView()
                    }
                    Toggle("Weekly summary", isOn: .constant(false))
                }

                Section("Environment") {
                    LabeledContent("Mode", value: appEnvironment.configuration.environmentName)
                    LabeledContent("API", value: appEnvironment.configuration.baseURL.absoluteString)
                }

                Section {
                    PrimaryButton(title: "Save Changes", icon: "checkmark.circle.fill") {
                        saveName()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private func saveName() {
        viewModel.updateDisplayName(editedName)
    }
}

#Preview {
    ProfileView()
        .environment(\.appTheme, .default)
        .environmentObject(AppEnvironment())
        .environmentObject(FamilyRoleStore())
        .environmentObject(AppRouter())
}
