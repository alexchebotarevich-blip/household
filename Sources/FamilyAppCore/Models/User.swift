import Foundation

public struct User: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var email: String
    public var displayName: String?
    public var familyID: String?

    public init(id: String, email: String, displayName: String? = nil, familyID: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.familyID = familyID
    }

    public func withFamily(id: String) -> User {
        var copy = self
        copy.familyID = id
        return copy
    }

    public func updating(displayName: String?) -> User {
        var copy = self
        copy.displayName = displayName
        return copy
    }
}
