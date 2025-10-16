import Foundation

public enum RepositoryError: Error {
    case notFound
    case alreadyExists
    case invalidCredentials
    case notAuthenticated
    case underlying(String)
}

public protocol AuthenticationRepository: AnyObject {
    var currentUser: AppUser? { get }

    @discardableResult
    func signUp(email: String, password: String, displayName: String) throws -> AppUser

    @discardableResult
    func signIn(email: String, password: String) throws -> AppUser

    func signOut() throws

    @discardableResult
    func observeAuthChanges(_ listener: @escaping @Sendable (AppUser?) -> Void) -> Cancellable
}

public protocol FamilyRepository: AnyObject {
    func create(_ family: Family) throws
    func update(_ family: Family) throws
    func fetchFamily(id: String) throws -> Family
    func families(for userID: String) throws -> [Family]

    @discardableResult
    func observeFamily(
        id: String,
        handler: @escaping @Sendable (Result<Family, Error>) -> Void
    ) -> Cancellable
}

public protocol TaskRepository: AnyObject {
    func create(_ task: TaskItem) throws
    func update(_ task: TaskItem) throws
    func delete(taskID: String, familyID: String) throws
    func tasks(for familyID: String) throws -> [TaskItem]

    @discardableResult
    func observeTaskEvents(
        for familyID: String,
        handler: @escaping @Sendable (Result<[FirestoreListenerEvent<TaskItem>], Error>) -> Void
    ) -> Cancellable
}

public protocol ShoppingRepository: AnyObject {
    func create(_ item: ShoppingItem) throws
    func update(_ item: ShoppingItem) throws
    func delete(itemID: String, familyID: String) throws
    func items(for familyID: String) throws -> [ShoppingItem]

    @discardableResult
    func observeShoppingEvents(
        for familyID: String,
        handler: @escaping @Sendable (Result<[FirestoreListenerEvent<ShoppingItem>], Error>) -> Void
    ) -> Cancellable
}

public protocol ActivityLogRepository: AnyObject {
    func append(_ log: ActivityLog)
    func activityLogs(for familyID: String) -> [ActivityLog]
}
