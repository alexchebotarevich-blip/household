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
}
