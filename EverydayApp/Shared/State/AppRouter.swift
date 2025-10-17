import Foundation

enum AppTab: Hashable {
    case home
    case tasks
    case shopping
    case profile
}

final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var highlightedTaskID: UUID?
    @Published var highlightedShoppingListID: String?
    @Published var pendingRewardMessage: String?

    func handle(notification payload: NotificationPayload, allowedRoleIDs: [String]) {
        if let roleID = payload.roleID, !allowedRoleIDs.contains(roleID) {
            // Ignore notifications that the current user is not authorised to access.
            return
        }

        if let deeplink = payload.deeplink, let url = URL(string: deeplink) {
            handle(deeplink: url, allowedRoleIDs: allowedRoleIDs)
            return
        }

        switch payload.target {
        case .task:
            selectedTab = .tasks
            if let identifier = payload.identifier, let uuid = UUID(uuidString: identifier) {
                highlightedTaskID = uuid
            }
        case .shopping:
            selectedTab = .shopping
            highlightedShoppingListID = payload.identifier ?? payload.category
        case .reward:
            selectedTab = .home
            pendingRewardMessage = payload.message ?? payload.identifier
        case .profile:
            selectedTab = .profile
        case .home:
            selectedTab = .home
        }
    }

    func handle(deeplink url: URL, allowedRoleIDs _: [String]) {
        guard url.scheme == "everydayapp" else { return }
        switch url.host {
        case "tasks":
            selectedTab = .tasks
            if let id = UUID(uuidString: url.lastPathComponent) {
                highlightedTaskID = id
            }
        case "shopping":
            selectedTab = .shopping
            highlightedShoppingListID = url.lastPathComponent
        case "profile":
            selectedTab = .profile
        default:
            selectedTab = .home
        }
    }

    func clearHighlights() {
        highlightedTaskID = nil
        highlightedShoppingListID = nil
        pendingRewardMessage = nil
    }

    func clearTaskHighlight() {
        highlightedTaskID = nil
    }

    func clearShoppingHighlight() {
        highlightedShoppingListID = nil
    }
}
