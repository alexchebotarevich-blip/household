#if canImport(SwiftUI)
import SwiftUI
import Combine
import FamilyHubCore

private enum AuthRoute: Hashable {
    case signUp
    case login
    case passwordReset
}

private struct OnboardingRoleTemplatesKey: EnvironmentKey {
    static let defaultValue: [FamilyRole.Template] = FamilyRole.defaultTemplates
}

private struct OnboardingRoleSelectionHandlerKey: EnvironmentKey {
    static let defaultValue: (FamilyRole.Template) -> Void = { _ in }
}

extension EnvironmentValues {
    public var onboardingRoleTemplates: [FamilyRole.Template] {
        get { self[OnboardingRoleTemplatesKey.self] }
        set { self[OnboardingRoleTemplatesKey.self] = newValue }
    }

    public var onboardingRoleSelectionHandler: (FamilyRole.Template) -> Void {
        get { self[OnboardingRoleSelectionHandlerKey.self] }
        set { self[OnboardingRoleSelectionHandlerKey.self] = newValue }
    }
}

@MainActor
public final class SessionObserver: ObservableObject {
    @Published public private(set) var state: SessionState

    private let sessionStore: SessionStore
    private var updatesTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        self.state = .loggedOut

        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            let current = await sessionStore.currentState()
            await MainActor.run {
                self.state = current
            }
        }

        updatesTask = Task { [weak self] in
            guard let self else { return }
            let stream = await sessionStore.updates()
            for await newState in stream {
                await MainActor.run {
                    self.state = newState
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        bootstrapTask?.cancel()
    }
}

@MainActor
public final class AuthenticationViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var displayName: String = ""
    @Published public var errorMessage: String?
    @Published public var infoMessage: String?
    @Published public var isLoading: Bool = false

    private let controller: AuthenticationController

    public init(controller: AuthenticationController) {
        self.controller = controller
    }

    public func prepareForSignUp() {
        displayName = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
        infoMessage = nil
    }

    public func prepareForLogin(preserveEmail: Bool = true) {
        if !preserveEmail { email = "" }
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
        infoMessage = nil
    }

    public func prepareForPasswordReset() {
        errorMessage = nil
        infoMessage = nil
    }

    public func signUp() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = SignUpRequest(
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName
        )

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.signUp(request: request)
                self.infoMessage = "Account created! Finish setting up your family."
                self.clearSensitiveData(keepEmail: true)
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isLoading = false
        }
    }

    public func login() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        let request = LoginRequest(email: email, password: password)

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.login(request: request)
                self.clearSensitiveData(keepEmail: true)
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isLoading = false
        }
    }

    public func sendPasswordReset() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        let targetEmail = email

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.sendPasswordReset(email: targetEmail)
                self.infoMessage = "A reset link was sent to \(targetEmail)."
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isLoading = false
        }
    }

    public func signInWithApple() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.signInWithApple()
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isLoading = false
        }
    }

    public func restoreSession() async {
        await controller.restoreSession()
    }

    private func clearSensitiveData(keepEmail: Bool) {
        password = ""
        confirmPassword = ""
        if keepEmail == false {
            email = ""
        }
    }

    private func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

@MainActor
public final class FamilyOnboardingViewModel: ObservableObject {
    @Published public var familyName: String = ""
    @Published public var familyUsername: String = ""
    @Published public var familyLastName: String = ""
    @Published public var searchUsername: String = ""
    @Published public var searchLastName: String = ""
    @Published public var invitationCode: String = ""
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isCreatingFamily: Bool = false
    @Published public var isJoiningFamily: Bool = false
    @Published public var isGeneratingInvitation: Bool = false
    @Published public var lastGeneratedInvitation: FamilyInvitation?

    private let controller: FamilyOnboardingController

    public init(controller: FamilyOnboardingController) {
        self.controller = controller
    }

    public func createFamily() {
        guard isCreatingFamily == false else { return }
        isCreatingFamily = true
        errorMessage = nil
        successMessage = nil

        let request = CreateFamilyRequest(
            name: familyName,
            username: familyUsername,
            lastName: familyLastName
        )

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.createFamily(request: request)
                self.successMessage = "Family created!"
                self.clearCreateForm()
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isCreatingFamily = false
        }
    }

    public func joinByUsername() {
        guard isJoiningFamily == false else { return }
        let trimmed = searchUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            successMessage = nil
            errorMessage = FamilyOnboardingError.missingSearchCriteria.errorDescription
            return
        }
        isJoiningFamily = true
        errorMessage = nil
        successMessage = nil

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.joinFamily(byUsername: trimmed)
                self.successMessage = "Joined family successfully!"
                self.clearJoinForm()
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isJoiningFamily = false
        }
    }

    public func joinByLastName() {
        guard isJoiningFamily == false else { return }
        let trimmed = searchLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            successMessage = nil
            errorMessage = FamilyOnboardingError.missingSearchCriteria.errorDescription
            return
        }
        isJoiningFamily = true
        errorMessage = nil
        successMessage = nil

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.joinFamily(byLastName: trimmed)
                self.successMessage = "Joined family successfully!"
                self.clearJoinForm()
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isJoiningFamily = false
        }
    }

    public func joinWithInvitation() {
        guard isJoiningFamily == false else { return }
        let trimmed = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            successMessage = nil
            errorMessage = FamilyOnboardingError.missingSearchCriteria.errorDescription
            return
        }
        isJoiningFamily = true
        errorMessage = nil
        successMessage = nil

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                try await controller.joinFamily(usingInvitation: trimmed)
                self.successMessage = "Joined family successfully!"
                self.clearJoinForm()
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isJoiningFamily = false
        }
    }

    public func inviteMembers() {
        guard isGeneratingInvitation == false else { return }
        isGeneratingInvitation = true
        errorMessage = nil
        successMessage = nil

        Task { [weak self] @MainActor in
            guard let self else { return }
            do {
                let invitation = try await controller.inviteMembers()
                self.lastGeneratedInvitation = invitation
                self.successMessage = "Share this code: \(invitation.code)"
            } catch {
                self.errorMessage = self.message(for: error)
            }
            self.isGeneratingInvitation = false
        }
    }

    public func resetMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func clearCreateForm() {
        familyName = ""
        familyUsername = ""
        familyLastName = ""
    }

    private func clearJoinForm() {
        searchUsername = ""
        searchLastName = ""
        invitationCode = ""
    }

    private func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

public struct OnboardingFlowView: View {
    @StateObject private var sessionObserver: SessionObserver
    @StateObject private var authenticationViewModel: AuthenticationViewModel
    @StateObject private var familyViewModel: FamilyOnboardingViewModel
    @State private var navigationPath: [AuthRoute] = []

    public init(
        sessionStore: SessionStore,
        authenticationController: AuthenticationController,
        familyController: FamilyOnboardingController
    ) {
        _sessionObserver = StateObject(wrappedValue: SessionObserver(sessionStore: sessionStore))
        _authenticationViewModel = StateObject(wrappedValue: AuthenticationViewModel(controller: authenticationController))
        _familyViewModel = StateObject(wrappedValue: FamilyOnboardingViewModel(controller: familyController))
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch sessionObserver.state {
                case .loggedOut:
                    WelcomeView(
                        viewModel: authenticationViewModel,
                        onSignUp: {
                            authenticationViewModel.prepareForSignUp()
                            navigationPath.append(.signUp)
                        },
                        onLogin: {
                            authenticationViewModel.prepareForLogin()
                            navigationPath.append(.login)
                        },
                        onAppleSignIn: {
                            authenticationViewModel.signInWithApple()
                        }
                    )
                case let .awaitingFamily(user):
                    FamilyOnboardingView(user: user, viewModel: familyViewModel)
                case let .active(user, family):
                    ActiveFamilyView(user: user, family: family, viewModel: familyViewModel)
                }
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signUp:
                    SignUpView(viewModel: authenticationViewModel)
                case .login:
                    LoginView(
                        viewModel: authenticationViewModel,
                        onPasswordReset: {
                            authenticationViewModel.prepareForPasswordReset()
                            navigationPath.append(.passwordReset)
                        }
                    )
                case .passwordReset:
                    PasswordResetView(viewModel: authenticationViewModel)
                }
            }
        }
        .onChange(of: sessionObserver.state) { _ in
            navigationPath.removeAll()
        }
        .task {
            await authenticationViewModel.restoreSession()
        }
    }
}

private struct WelcomeView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onSignUp: () -> Void
    let onLogin: () -> Void
    let onAppleSignIn: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("Welcome to FamilyCircle")
                    .font(.largeTitle.bold())
                Text("Create a shared space for your loved ones with secure messaging and planning.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 16) {
                Button(action: onSignUp) {
                    Label("Get Started", systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onLogin) {
                    Label("Log In", systemImage: "person.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onAppleSignIn) {
                    Label("Sign in with Apple", systemImage: "applelogo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isLoading)
            }
            Spacer()
            if let message = viewModel.errorMessage {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            if let info = viewModel.infoMessage {
                Text(info)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
        }
    }
}

private struct SignUpView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            }

            Section("Profile") {
                TextField("Display name (optional)", text: $viewModel.displayName)
                    .textContentType(.name)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            if let info = viewModel.infoMessage {
                Section {
                    Text(info)
                        .foregroundColor(.green)
                }
            }

            Section {
                Button {
                    viewModel.signUp()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Sign Up")
    }
}

private struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onPasswordReset: () -> Void

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    viewModel.login()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)

                Button("Forgot password?", action: onPasswordReset)
                    .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Log In")
    }
}

private struct PasswordResetView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            if let info = viewModel.infoMessage {
                Section {
                    Text(info)
                        .foregroundColor(.green)
                }
            }

            Section {
                Button {
                    viewModel.sendPasswordReset()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Reset Email")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Reset Password")
    }
}

private struct FamilyOnboardingView: View {
    let user: User
    @ObservedObject var viewModel: FamilyOnboardingViewModel
    @Environment(\.onboardingRoleTemplates) private var roleTemplates
    @Environment(\.onboardingRoleSelectionHandler) private var roleSelectionHandler
    @State private var selectedRoleTemplateID: String = ""

    var body: some View {
        Form {
            Section("Create a new family") {
                TextField("Family name", text: $viewModel.familyName)
                TextField("Family username", text: $viewModel.familyUsername)
                    .textInputAutocapitalization(.never)
                TextField("Family last name", text: $viewModel.familyLastName)

                Button {
                    if let template = selectedTemplate {
                        roleSelectionHandler(template)
                    }
                    viewModel.createFamily()
                } label: {
                    if viewModel.isCreatingFamily {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Family")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isCreatingFamily)
            }

            Section("Your role") {
                Picker("Primary role", selection: $selectedRoleTemplateID) {
                    ForEach(roleTemplates, id: \.id) { template in
                        Text(template.title).tag(template.id)
                    }
                }
                .pickerStyle(.segmented)

                if let template = selectedTemplate {
                    Text(template.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Join by username") {
                TextField("Family username", text: $viewModel.searchUsername)
                    .textInputAutocapitalization(.never)
                Button("Join by Username") {
                    viewModel.joinByUsername()
                }
                .disabled(viewModel.isJoiningFamily)
            }

            Section("Join by last name") {
                TextField("Family last name", text: $viewModel.searchLastName)
                Button("Join by Last Name") {
                    viewModel.joinByLastName()
                }
                .disabled(viewModel.isJoiningFamily)
            }

            Section("Join with invitation code") {
                TextField("Invitation code", text: $viewModel.invitationCode)
                    .textInputAutocapitalization(.never)
                Button("Join with Code") {
                    viewModel.joinWithInvitation()
                }
                .disabled(viewModel.isJoiningFamily)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signed in as \(user.email)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            if let info = viewModel.successMessage {
                Section {
                    Text(info)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Family Setup")
        .onAppear {
            if selectedRoleTemplateID.isEmpty {
                selectedRoleTemplateID = roleTemplates.first?.id ?? ""
            }
            if let template = selectedTemplate {
                roleSelectionHandler(template)
            }
        }
        .onChange(of: selectedRoleTemplateID) { newValue in
            guard let template = roleTemplates.first(where: { $0.id == newValue }) else { return }
            roleSelectionHandler(template)
        }
    }

    private var selectedTemplate: FamilyRole.Template? {
        roleTemplates.first(where: { $0.id == selectedRoleTemplateID }) ?? roleTemplates.first
    }
}

private struct ActiveFamilyView: View {
    let user: User
    let family: Family
    @ObservedObject var viewModel: FamilyOnboardingViewModel

    var body: some View {
        List {
            Section("Family Summary") {
                LabeledContent("Family name", value: family.name)
                LabeledContent("Username", value: family.username)
                LabeledContent("Members", value: "\(family.members.count)")
            }

            Section("Invitation") {
                Button {
                    viewModel.inviteMembers()
                } label: {
                    if viewModel.isGeneratingInvitation {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Generate invitation link")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isGeneratingInvitation)

                if let invitation = viewModel.lastGeneratedInvitation {
                    Text("Invitation code: \(invitation.code)")
                        .font(.headline)
                    if #available(iOS 16.0, macOS 13.0, *) {
                        ShareLink(
                            item: invitation.code,
                            message: Text("Join my family '\(family.name)' with code \(invitation.code)"),
                            preview: SharePreview("Invite to \(family.name)")
                        ) {
                            Label("Share invitation", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }

            Section("Account") {
                Text("Signed in as \(user.email)")
                    .font(.footnote)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            if let info = viewModel.successMessage {
                Section {
                    Text(info)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle(family.name)
    }
}

#endif
