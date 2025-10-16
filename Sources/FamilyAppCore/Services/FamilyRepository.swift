import Foundation

public enum FamilyRepositoryError: Error, Equatable, LocalizedError, Sendable {
    case familyAlreadyExists
    case familyNotFound
    case invitationNotFound
    case userAlreadyMember
    case userNotAuthenticated
    case invalidUsername

    public var errorDescription: String? {
        switch self {
        case .familyAlreadyExists:
            return "A family with that username already exists."
        case .familyNotFound:
            return "We couldn't find a matching family."
        case .invitationNotFound:
            return "Invitation code not found or expired."
        case .userAlreadyMember:
            return "User is already a member of this family."
        case .userNotAuthenticated:
            return "The current user is not authenticated."
        case .invalidUsername:
            return "Please choose a username with at least 3 characters and no spaces."
        }
    }
}

public protocol FamilyRepository: Sendable {
    func createFamily(name: String, username: String, lastName: String, ownerID: String) async throws -> Family
    func joinFamily(byUsername username: String, userID: String) async throws -> Family
    func joinFamily(byLastName lastName: String, userID: String) async throws -> Family
    func joinFamily(usingInvitation code: String, userID: String) async throws -> Family
    func fetchFamily(id: String) async throws -> Family?
    func generateInvitation(for familyID: String, invitedBy userID: String) async throws -> FamilyInvitation
}
