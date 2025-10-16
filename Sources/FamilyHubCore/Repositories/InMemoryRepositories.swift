import Foundation

public final class InMemoryAuthenticationRepository: AuthenticationRepository {
    private let store: InMemoryRepositoryStore
    private let stateQueue = DispatchQueue(label: "InMemoryAuthenticationRepository.state", attributes: .concurrent)
    private let listenersQueue = DispatchQueue(label: "InMemoryAuthenticationRepository.listeners", attributes: .concurrent)
    private var currentUserID: String?
    private var listeners: [UUID: @Sendable (AppUser?) -> Void] = [:]

    public init(store: InMemoryRepositoryStore = InMemoryRepositoryStore()) {
        self.store = store
    }

    public var currentUser: AppUser? {
        var identifier: String?
        stateQueue.sync {
            identifier = currentUserID
        }
        guard let identifier, let user = store.user(withID: identifier) else { return nil }
        return user
    }

    @discardableResult
    public func signUp(email: String, password: String, displayName: String) throws -> AppUser {
        if store.user(withEmail: email) != nil {
            throw RepositoryError.alreadyExists
        }

        let identifier = UUID().uuidString
        let timestamp = Date()
        let user = AppUser(
            id: identifier,
            email: email,
            displayName: displayName,
            photoURL: nil,
            familyID: nil,
            roleIDs: [],
            deviceTokens: [],
            isActive: true,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        store.saveUser(user, password: password)
        updateCurrentUser(id: identifier)
        notifyListeners(with: user)
        return user
    }

    @discardableResult
    public func signIn(email: String, password: String) throws -> AppUser {
        guard let record = store.user(withEmail: email) else {
            throw RepositoryError.notFound
        }

        guard record.password == password else {
            throw RepositoryError.invalidCredentials
        }

        updateCurrentUser(id: record.user.id)
        notifyListeners(with: record.user)
        return record.user
    }

    public func signOut() throws {
        guard currentUser != nil else {
            throw RepositoryError.notAuthenticated
        }

        updateCurrentUser(id: nil)
        notifyListeners(with: nil)
    }

    @discardableResult
    public func observeAuthChanges(_ listener: @escaping @Sendable (AppUser?) -> Void) -> Cancellable {
        let identifier = UUID()

        listenersQueue.async(flags: .barrier) {
            self.listeners[identifier] = listener
        }

        listener(currentUser)

        return AnyRepositoryCancellable { [weak self] in
            self?.listenersQueue.async(flags: .barrier) {
                self?.listeners.removeValue(forKey: identifier)
            }
        }
    }

    private func updateCurrentUser(id: String?) {
        stateQueue.sync(flags: .barrier) {
            self.currentUserID = id
        }
    }

    private func notifyListeners(with user: AppUser?) {
        var callbacks: [@Sendable (AppUser?) -> Void] = []
        listenersQueue.sync {
            callbacks = Array(listeners.values)
        }

        guard !callbacks.isEmpty else { return }
        callbacks.forEach { $0(user) }
    }
}

public final class InMemoryFamilyRepository: FamilyRepository {
    private let store: InMemoryRepositoryStore
    private let listenerCenter: FirestoreListenerCenter

    public init(
        store: InMemoryRepositoryStore = InMemoryRepositoryStore(),
        listenerCenter: FirestoreListenerCenter = FirestoreListenerCenter()
    ) {
        self.store = store
        self.listenerCenter = listenerCenter
    }

    public func create(_ family: Family) throws {
        if store.family(withID: family.id) != nil {
            throw RepositoryError.alreadyExists
        }

        store.saveFamily(family)
        listenerCenter.publish([.added(family)], for: descriptor(for: family.id))
    }

    public func update(_ family: Family) throws {
        guard store.family(withID: family.id) != nil else {
            throw RepositoryError.notFound
        }

        store.saveFamily(family)
        listenerCenter.publish([.modified(family)], for: descriptor(for: family.id))
    }

    public func fetchFamily(id: String) throws -> Family {
        guard let family = store.family(withID: id) else {
            throw RepositoryError.notFound
        }
        return family
    }

    public func families(for userID: String) throws -> [Family] {
        store.families(forUserID: userID)
    }

    @discardableResult
    public func observeFamily(
        id: String,
        handler: @escaping @Sendable (Result<Family, Error>) -> Void
    ) -> Cancellable {
        if let family = store.family(withID: id) {
            handler(.success(family))
        }

        return listenerCenter.listen(to: descriptor(for: id), as: Family.self) { result in
            switch result {
            case .success(let events):
                guard let lastEvent = events.last else { return }
                switch lastEvent {
                case .added(let family), .modified(let family):
                    handler(.success(family))
                case .removed:
                    handler(.failure(RepositoryError.notFound))
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }

    private func descriptor(for id: String) -> FirestoreCollectionDescriptor {
        FirestoreCollectionDescriptor(collection: .families, scopeIdentifier: id)
    }
}

public final class InMemoryTaskRepository: TaskRepository {
    private let store: InMemoryRepositoryStore
    private let listenerCenter: FirestoreListenerCenter

    public init(
        store: InMemoryRepositoryStore = InMemoryRepositoryStore(),
        listenerCenter: FirestoreListenerCenter = FirestoreListenerCenter()
    ) {
        self.store = store
        self.listenerCenter = listenerCenter
    }

    public func create(_ task: TaskItem) throws {
        if store.task(familyID: task.familyID, taskID: task.id) != nil {
            throw RepositoryError.alreadyExists
        }

        store.saveTask(task)
        listenerCenter.publish([.added(task)], for: descriptor(for: task.familyID))
    }

    public func update(_ task: TaskItem) throws {
        guard store.task(familyID: task.familyID, taskID: task.id) != nil else {
            throw RepositoryError.notFound
        }

        store.saveTask(task)
        listenerCenter.publish([.modified(task)], for: descriptor(for: task.familyID))
    }

    public func delete(taskID: String, familyID: String) throws {
        guard let removed = store.deleteTask(familyID: familyID, taskID: taskID) else {
            throw RepositoryError.notFound
        }

        listenerCenter.publish([.removed(removed)], for: descriptor(for: familyID))
    }

    public func tasks(for familyID: String) throws -> [TaskItem] {
        store.tasks(for: familyID)
    }

    @discardableResult
    public func observeTaskEvents(
        for familyID: String,
        handler: @escaping @Sendable (Result<[FirestoreListenerEvent<TaskItem>], Error>) -> Void
    ) -> Cancellable {
        let descriptor = descriptor(for: familyID)
        let existingTasks = store.tasks(for: familyID)
        if !existingTasks.isEmpty {
            handler(.success(existingTasks.map { FirestoreListenerEvent.added($0) }))
        }

        return listenerCenter.listen(to: descriptor, as: TaskItem.self, onEvent: handler)
    }

    private func descriptor(for familyID: String) -> FirestoreCollectionDescriptor {
        FirestoreCollectionDescriptor(collection: .tasks, scopeIdentifier: familyID)
    }
}

public final class InMemoryShoppingRepository: ShoppingRepository {
    private let store: InMemoryRepositoryStore
    private let listenerCenter: FirestoreListenerCenter

    public init(
        store: InMemoryRepositoryStore = InMemoryRepositoryStore(),
        listenerCenter: FirestoreListenerCenter = FirestoreListenerCenter()
    ) {
        self.store = store
        self.listenerCenter = listenerCenter
    }

    public func create(_ item: ShoppingItem) throws {
        if store.shoppingItems(for: item.familyID).contains(where: { $0.id == item.id }) {
            throw RepositoryError.alreadyExists
        }

        store.saveShoppingItem(item)
        listenerCenter.publish([.added(item)], for: descriptor(for: item.familyID))
    }

    public func update(_ item: ShoppingItem) throws {
        guard store.shoppingItems(for: item.familyID).contains(where: { $0.id == item.id }) else {
            throw RepositoryError.notFound
        }

        store.saveShoppingItem(item)
        listenerCenter.publish([.modified(item)], for: descriptor(for: item.familyID))
    }

    public func delete(itemID: String, familyID: String) throws {
        guard let removed = store.deleteShoppingItem(familyID: familyID, itemID: itemID) else {
            throw RepositoryError.notFound
        }

        listenerCenter.publish([.removed(removed)], for: descriptor(for: familyID))
    }

    public func items(for familyID: String) throws -> [ShoppingItem] {
        store.shoppingItems(for: familyID)
    }

    @discardableResult
    public func observeShoppingEvents(
        for familyID: String,
        handler: @escaping @Sendable (Result<[FirestoreListenerEvent<ShoppingItem>], Error>) -> Void
    ) -> Cancellable {
        let descriptor = descriptor(for: familyID)
        let existingItems = store.shoppingItems(for: familyID)
        if !existingItems.isEmpty {
            handler(.success(existingItems.map { FirestoreListenerEvent.added($0) }))
        }

        return listenerCenter.listen(to: descriptor, as: ShoppingItem.self, onEvent: handler)
    }

    private func descriptor(for familyID: String) -> FirestoreCollectionDescriptor {
        FirestoreCollectionDescriptor(collection: .shoppingItems, scopeIdentifier: familyID)
    }
}

public final class InMemoryActivityLogRepository: ActivityLogRepository {
    private let store: InMemoryRepositoryStore

    public init(store: InMemoryRepositoryStore = InMemoryRepositoryStore()) {
        self.store = store
    }

    public func append(_ log: ActivityLog) {
        store.appendActivityLog(log)
    }

    public func activityLogs(for familyID: String) -> [ActivityLog] {
        store.activityLogs(for: familyID)
    }
}

private struct AnyRepositoryCancellable: Cancellable, Sendable {
    private let handler: @Sendable () -> Void

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func cancel() {
        handler()
    }
}
