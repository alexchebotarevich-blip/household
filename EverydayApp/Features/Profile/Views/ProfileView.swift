import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appEnvironment: AppEnvironment
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
                    ForEach(viewModel.profile.householdMembers, id: \.self) { member in
                        Text(member)
                    }
                }

                Section("Preferences") {
                    Toggle("Push notifications", isOn: .constant(true))
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
}
