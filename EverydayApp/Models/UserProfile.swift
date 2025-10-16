import Foundation

struct UserProfile: Identifiable, Codable {
    struct HouseholdMember: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var roleID: String?

        init(id: UUID = UUID(), name: String, roleID: String? = nil) {
            self.id = id
            self.name = name
            self.roleID = roleID
        }
    }

    let id: UUID
    var displayName: String
    var email: String
    var householdMembers: [HouseholdMember]

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String,
        householdMembers: [HouseholdMember] = []
    ) {
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
        householdMembers: [
            HouseholdMember(name: "Taylor", roleID: nil),
            HouseholdMember(name: "Noah", roleID: nil),
            HouseholdMember(name: "Quinn", roleID: nil)
        ]
    )
}
