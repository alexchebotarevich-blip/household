import Foundation

public struct SignUpRequest: Sendable {
    public let email: String
    public let password: String
    public let confirmPassword: String
    public let displayName: String?

    public init(email: String, password: String, confirmPassword: String, displayName: String?) {
        self.email = email
        self.password = password
        self.confirmPassword = confirmPassword
        self.displayName = displayName
    }
}

public struct LoginRequest: Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public actor AuthenticationController {
    private let authService: AuthService
    private let familyRepository: FamilyRepository
    private let sessionStore: SessionStore

    public init(authService: AuthService, familyRepository: FamilyRepository, sessionStore: SessionStore) {
        self.authService = authService
        self.familyRepository = familyRepository
        self.sessionStore = sessionStore
    }

    public func restoreSession() async {
        guard let user = authService.currentUser else {
            await sessionStore.update(.loggedOut)
            return
        }
        await route(user: user)
    }

    public func signUp(request: SignUpRequest) async throws {
        try validate(email: request.email)
        let sanitizedPassword = request.password.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedConfirmation = request.confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(password: sanitizedPassword)
        guard sanitizedPassword == sanitizedConfirmation else {
            throw AuthenticationFlowError.passwordsDoNotMatch
        }

        let normalizedEmail = request.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let user = try await authService.signUp(
            email: normalizedEmail,
            password: sanitizedPassword,
            displayName: request.displayName
        )
        await sessionStore.update(.awaitingFamily(user: user))
    }

    public func login(request: LoginRequest) async throws {
        try validate(email: request.email)
        let sanitizedPassword = request.password.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureNotEmpty(sanitizedPassword, field: "password")
        let normalizedEmail = request.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let user = try await authService.login(
            email: normalizedEmail,
            password: sanitizedPassword
        )
        await route(user: user)
    }

    public func sendPasswordReset(email: String) async throws {
        try validate(email: email)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await authService.sendPasswordReset(email: normalizedEmail)
    }

    public func signInWithApple() async throws {
        let user = try await authService.signInWithApple()
        await route(user: user)
    }

    public func logout() async throws {
        try authService.signOut()
        await sessionStore.update(.loggedOut)
    }

    private func route(user: User) async {
        if let familyID = user.familyID, let family = try? await familyRepository.fetchFamily(id: familyID) {
            let updatedFamily = family.addingMember(user.id)
            await sessionStore.update(.active(user: user.withFamily(id: familyID), family: updatedFamily))
        } else {
            await sessionStore.update(.awaitingFamily(user: user))
        }
    }

    private func validate(email: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureNotEmpty(trimmed, field: "email")
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw AuthenticationFlowError.invalidEmail
        }
    }

    private func validate(password: String) throws {
        try ensureNotEmpty(password, field: "password")
        guard password.count >= 6 else {
            throw AuthenticationFlowError.weakPassword
        }
    }

    private func ensureNotEmpty(_ value: String, field: String) throws {
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw AuthenticationFlowError.emptyField(field)
        }
    }
}
