import Foundation

public struct FamilyInvitation: Codable, Equatable, Sendable {
    public let code: String
    public let familyID: String
    public let invitedByUserID: String
    public let createdAt: Date

    public init(code: String, familyID: String, invitedByUserID: String, createdAt: Date = Date()) {
        self.code = code
        self.familyID = familyID
        self.invitedByUserID = invitedByUserID
        self.createdAt = createdAt
    }
}
