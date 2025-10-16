import Foundation

public struct CreateFamilyRequest: Sendable {
    public let name: String
    public let username: String
    public let lastName: String

    public init(name: String, username: String, lastName: String) {
        self.name = name
        self.username = username
        self.lastName = lastName
    }
}

public enum FamilyOnboardingError: Error, Equatable, LocalizedError, Sendable {
    case invalidState
    case missingSearchCriteria
    case emptyField(String)

    public var errorDescription: String? {
        switch self {
        case .invalidState:
            return "User must be authenticated before managing families."
        case .missingSearchCriteria:
            return "Please provide a family username, last name, or invitation code."
        case let .emptyField(field):
            return "The \(field) field cannot be empty."
        }
    }
}

public actor FamilyOnboardingController {
    private let repository: FamilyRepository
    private let sessionStore: SessionStore

    public init(repository: FamilyRepository, sessionStore: SessionStore) {
        self.repository = repository
        self.sessionStore = sessionStore
    }

    public func createFamily(request: CreateFamilyRequest) async throws {
        try ensureValidUsername(request.username)
        try ensureNotEmpty(request.name, field: "family name")
        try ensureNotEmpty(request.lastName, field: "last name")

        let state = await sessionStore.currentState()
        guard case let .awaitingFamily(user) = state else {
            throw FamilyOnboardingError.invalidState
        }

        let trimmedName = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = request.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = request.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let family = try await repository.createFamily(
            name: trimmedName,
            username: normalizedUsername,
            lastName: trimmedLastName,
            ownerID: user.id
        )
        let updatedUser = user.withFamily(id: family.id)
        await sessionStore.update(.active(user: updatedUser, family: family))
    }

    public func joinFamily(byUsername username: String) async throws {
        let user = try await currentAwaitingUser()
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let family = try await repository.joinFamily(byUsername: normalized, userID: user.id)
        await sessionStore.update(.active(user: user.withFamily(id: family.id), family: family))
    }

    public func joinFamily(byLastName lastName: String) async throws {
        let user = try await currentAwaitingUser()
        let trimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = try await repository.joinFamily(byLastName: trimmed, userID: user.id)
        await sessionStore.update(.active(user: user.withFamily(id: family.id), family: family))
    }

    public func joinFamily(usingInvitation code: String) async throws {
        let user = try await currentAwaitingUser()
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let family = try await repository.joinFamily(usingInvitation: normalizedCode, userID: user.id)
        await sessionStore.update(.active(user: user.withFamily(id: family.id), family: family))
    }

    public func inviteMembers() async throws -> FamilyInvitation {
        let state = await sessionStore.currentState()
        guard case let .active(user, family) = state else {
            throw FamilyOnboardingError.invalidState
        }
        return try await repository.generateInvitation(for: family.id, invitedBy: user.id)
    }

    private func currentAwaitingUser() async throws -> User {
        let state = await sessionStore.currentState()
        guard case let .awaitingFamily(user) = state else {
            throw FamilyOnboardingError.invalidState
        }
        return user
    }

    private func ensureValidUsername(_ username: String) throws {
        try ensureNotEmpty(username, field: "username")
        guard username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3,
              username.contains(" ") == false else {
            throw FamilyRepositoryError.invalidUsername
        }
    }

    private func ensureNotEmpty(_ value: String, field: String) throws {
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw FamilyOnboardingError.emptyField(field)
        }
    }
}
