import Foundation

final class GamificationStore {
    static let shared = GamificationStore()

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func loadProfile(for userID: String) -> GamificationProfile {
        let key = storageKey(for: userID)
        guard let data = userDefaults.data(forKey: key),
              let profile = try? decoder.decode(GamificationProfile.self, from: data) else {
            return GamificationProfile(userID: userID)
        }
        return profile
    }

    func saveProfile(_ profile: GamificationProfile) {
        let key = storageKey(for: profile.userID)
        if let data = try? encoder.encode(profile) {
            userDefaults.set(data, forKey: key)
        }
    }

    private func storageKey(for userID: String) -> String {
        "gamification-profile-\(userID)"
    }
}
