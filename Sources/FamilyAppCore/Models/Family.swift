import Foundation

public struct Family: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var username: String
    public var lastName: String
    public var invitationCode: String
    public var members: Set<String>

    public init(
        id: String,
        name: String,
        username: String,
        lastName: String,
        invitationCode: String,
        members: Set<String>
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.lastName = lastName
        self.invitationCode = invitationCode
        self.members = members
    }

    public func addingMember(_ memberID: String) -> Family {
        var copy = self
        copy.members.insert(memberID)
        return copy
    }
}
