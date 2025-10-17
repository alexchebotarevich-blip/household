import Foundation

struct NotificationPayload {
    enum Target: String {
        case task
        case shopping
        case reward
        case profile
        case home
    }

    enum Keys {
        static let target = "target"
        static let identifier = "resource_id"
        static let roleIdentifier = "role_id"
        static let category = "category"
        static let deeplink = "deeplink"
        static let message = "message"
    }

    let target: Target
    let identifier: String?
    let roleID: String?
    let category: String?
    let deeplink: String?
    let message: String?
    let userInfo: [String: Any]

    init?(userInfo: [AnyHashable: Any]) {
        let dictionary = userInfo.reduce(into: [String: Any]()) { partialResult, pair in
            if let key = pair.key as? String {
                partialResult[key] = pair.value
            }
        }

        guard let targetString = dictionary[Keys.target] as? String,
              let target = Target(rawValue: targetString) else {
            return nil
        }

        self.target = target
        self.identifier = dictionary[Keys.identifier] as? String
        self.roleID = dictionary[Keys.roleIdentifier] as? String
        self.category = dictionary[Keys.category] as? String
        self.deeplink = dictionary[Keys.deeplink] as? String
        self.message = dictionary[Keys.message] as? String
        self.userInfo = dictionary
    }
}
