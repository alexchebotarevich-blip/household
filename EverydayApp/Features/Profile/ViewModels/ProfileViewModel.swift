import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile

    init(profile: UserProfile = .preview) {
        self.profile = profile
    }

    func updateDisplayName(_ name: String) {
        profile.displayName = name
    }

    func assign(roleID: String?, to memberID: UUID) {
        guard let index = profile.householdMembers.firstIndex(where: { $0.id == memberID }) else { return }
        profile.householdMembers[index].roleID = roleID
    }
}
