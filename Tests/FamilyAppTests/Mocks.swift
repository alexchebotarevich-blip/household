import Foundation
@testable import FamilyAppCore

final class MockAuthService: AuthService, @unchecked Sendable {
    var currentUser: User?

    var signUpHandler: ((String, String, String?) throws -> User)?
    var loginHandler: ((String, String) throws -> User)?
    var passwordResetHandler: ((String) throws -> Void)?
    var appleHandler: (() throws -> User)?
    var signOutHandler: (() throws -> Void)?

    func signUp(email: String, password: String, displayName: String?) async throws -> User {
        if let handler = signUpHandler {
            let user = try handler(email, password, displayName)
            currentUser = user
            return user
        }
        let user = User(id: UUID().uuidString, email: email, displayName: displayName)
        currentUser = user
        return user
    }

    func login(email: String, password: String) async throws -> User {
        if let handler = loginHandler {
            let user = try handler(email, password)
            currentUser = user
            return user
        }
        throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No login handler set"])
    }

    func sendPasswordReset(email: String) async throws {
        if let handler = passwordResetHandler {
            try handler(email)
            return
        }
    }

    func signInWithApple() async throws -> User {
        if let handler = appleHandler {
            let user = try handler()
            currentUser = user
            return user
        }
        throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In not configured"])
    }

    func signOut() throws {
        if let handler = signOutHandler {
            try handler()
        }
        currentUser = nil
    }
}

actor MockFamilyRepository: FamilyRepository {
    private var families: [String: Family] = [:]
    private var usernameLookup: [String: String] = [:]
    private var invitations: [String: FamilyInvitation] = [:]

    func createFamily(name: String, username: String, lastName: String, ownerID: String) async throws -> Family {
        let normalized = username.lowercased()
        guard usernameLookup[normalized] == nil else {
            throw FamilyRepositoryError.familyAlreadyExists
        }
        let familyID = UUID().uuidString
        let invitationCode = generateCode()
        let family = Family(
            id: familyID,
            name: name,
            username: normalized,
            lastName: lastName,
            invitationCode: invitationCode,
            members: Set([ownerID])
        )
        families[familyID] = family
        usernameLookup[normalized] = familyID
        invitations[invitationCode] = FamilyInvitation(code: invitationCode, familyID: familyID, invitedByUserID: ownerID)
        return family
    }

    func joinFamily(byUsername username: String, userID: String) async throws -> Family {
        let normalized = username.lowercased()
        guard let familyID = usernameLookup[normalized], var family = families[familyID] else {
            throw FamilyRepositoryError.familyNotFound
        }
        guard family.members.insert(userID).inserted else {
            throw FamilyRepositoryError.userAlreadyMember
        }
        families[familyID] = family
        return family
    }

    func joinFamily(byLastName lastName: String, userID: String) async throws -> Family {
        guard let family = families.values.first(where: { $0.lastName.caseInsensitiveCompare(lastName) == .orderedSame }) else {
            throw FamilyRepositoryError.familyNotFound
        }
        return try await joinFamily(usingInvitation: family.invitationCode, userID: userID)
    }

    func joinFamily(usingInvitation code: String, userID: String) async throws -> Family {
        let normalized = code.uppercased()
        guard let invitation = invitations[normalized], var family = families[invitation.familyID] else {
            throw FamilyRepositoryError.invitationNotFound
        }
        guard family.members.insert(userID).inserted else {
            throw FamilyRepositoryError.userAlreadyMember
        }
        families[family.id] = family
        return family
    }

    func fetchFamily(id: String) async throws -> Family? {
        families[id]
    }

    func generateInvitation(for familyID: String, invitedBy userID: String) async throws -> FamilyInvitation {
        guard var family = families[familyID] else { throw FamilyRepositoryError.familyNotFound }
        let code = generateCode()
        family.invitationCode = code
        families[familyID] = family
        let invitation = FamilyInvitation(code: code, familyID: familyID, invitedByUserID: userID)
        invitations[code] = invitation
        return invitation
    }

    private func generateCode() -> String {
        String(UUID().uuidString.prefix(6)).uppercased()
    }
}
