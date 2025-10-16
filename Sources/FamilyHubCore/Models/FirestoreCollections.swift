import Foundation

/// Known Firestore collection names used by the application.
public enum FirestoreCollection: String, CaseIterable, Codable, Sendable {
    case users
    case families
    case familyRoles
    case tasks
    case shoppingItems
    case activityLogs

    public var path: String { rawValue }
}

/// A protocol adopted by every model stored in Firestore. This keeps the data layer strongly typed
/// and makes it easy to share collection metadata.
public protocol FirestoreEntity: Codable, Identifiable, Equatable, Sendable {
    static var collection: FirestoreCollection { get }
}
