import Foundation

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var email: String
    var householdMembers: [String]

    init(id: UUID = UUID(), displayName: String, email: String, householdMembers: [String] = []) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.householdMembers = householdMembers
    }
}

extension UserProfile {
    static let preview = UserProfile(
        displayName: "Jess Harper",
        email: "jess@example.com",
        householdMembers: ["Taylor", "Noah", "Quinn"]
    )
}
