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

public final class InMemoryFamilyRoleRepository: FamilyRoleRepository {
    private let store: InMemoryRepositoryStore
    private let mutationQueue = DispatchQueue(label: "InMemoryFamilyRoleRepository.mutation", attributes: .concurrent)

    public init(store: InMemoryRepositoryStore = InMemoryRepositoryStore()) {
        self.store = store
    }

    public func roles(for familyID: String) throws -> [FamilyRole] {
        store.roles(familyID: familyID)
    }

    public func create(_ role: FamilyRole) throws {
        try performMutation(for: role.familyID) { existing in
            var roles = existing
            var newRole = normalize(role)
            try validateDuplicateTitle(newRole.title, excludingID: nil, within: roles)
            if newRole.displayOrder < 0 {
                newRole.displayOrder = (roles.map(\.displayOrder).max() ?? -1) + 1
            }
            roles.append(newRole)
            return persist(roles, familyID: role.familyID, forcedDefaultID: newRole.isDefault ? newRole.id : nil)
        }
    }

    public func update(_ role: FamilyRole) throws {
        try performMutation(for: role.familyID) { existing in
            guard existing.contains(where: { $0.id == role.id }) else {
                throw RepositoryError.notFound
            }
            var roles = existing
            var updatedRole = normalize(role)
            try validateDuplicateTitle(updatedRole.title, excludingID: updatedRole.id, within: roles)
            if let index = roles.firstIndex(where: { $0.id == updatedRole.id }) {
                updatedRole.updatedAt = Date()
                roles[index] = updatedRole
            }
            let defaultID = updatedRole.isDefault ? updatedRole.id : nil
            return persist(roles, familyID: role.familyID, forcedDefaultID: defaultID)
        }
    }

    public func delete(roleID: String, familyID: String) throws {
        try performMutation(for: familyID) { existing in
            guard let index = existing.firstIndex(where: { $0.id == roleID }) else {
                throw RepositoryError.notFound
            }
            var roles = existing
            let removed = roles.remove(at: index)
            if roles.isEmpty {
                roles.append(makeFallbackRole(for: familyID))
            }
            let defaultID = removed.isDefault ? roles.first?.id : nil
            return persist(roles, familyID: familyID, forcedDefaultID: defaultID)
        }
    }

    public func reorder(roleIDs: [String], in familyID: String) throws {
        try performMutation(for: familyID) { existing in
            guard existing.count == roleIDs.count else {
                throw RepositoryError.notFound
            }
            var lookup = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            var reordered: [FamilyRole] = []
            for identifier in roleIDs {
                guard var role = lookup.removeValue(forKey: identifier) else {
                    throw RepositoryError.notFound
                }
                role.displayOrder = reordered.count
                role.updatedAt = Date()
                reordered.append(role)
            }
            guard lookup.isEmpty else {
                throw RepositoryError.notFound
            }
            return persist(reordered, familyID: familyID)
        }
    }

    private func performMutation(for familyID: String, mutation: ([FamilyRole]) throws -> [FamilyRole]) throws {
        var mutationError: Error?
        mutationQueue.sync(flags: .barrier) {
            do {
                let roles = store.roles(familyID: familyID)
                let updated = try mutation(roles)
                store.replaceRoles(updated, for: familyID)
            } catch {
                mutationError = error
            }
        }
        if let error = mutationError {
            throw error
        }
    }

    private func persist(_ roles: [FamilyRole], familyID: String, forcedDefaultID: String? = nil) -> [FamilyRole] {
        guard roles.isEmpty == false else { return [] }
        var sorted = roles.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.displayOrder < rhs.displayOrder
        }

        let defaultID: String
        if let forcedDefaultID, sorted.contains(where: { $0.id == forcedDefaultID }) {
            defaultID = forcedDefaultID
        } else if let existingDefault = sorted.first(where: { $0.isDefault })?.id {
            defaultID = existingDefault
        } else if let first = sorted.first?.id {
            defaultID = first
        } else {
            defaultID = makeFallbackRole(for: familyID).id
        }

        let timestamp = Date()
        for index in sorted.indices {
            if sorted[index].displayOrder != index {
                sorted[index].displayOrder = index
                sorted[index].updatedAt = timestamp
            }
            let shouldBeDefault = sorted[index].id == defaultID
            if sorted[index].isDefault != shouldBeDefault {
                sorted[index].isDefault = shouldBeDefault
                sorted[index].updatedAt = timestamp
            }
        }
        return sorted
    }

    private func validateDuplicateTitle(_ title: String, excludingID: String?, within roles: [FamilyRole]) throws {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            throw RepositoryError.underlying("Role title cannot be empty.")
        }

        let duplicate = roles.contains { role in
            guard role.id != excludingID else { return false }
            return role.title.caseInsensitiveCompare(normalized) == .orderedSame
        }

        if duplicate {
            throw RepositoryError.alreadyExists
        }
    }

    private func normalize(_ role: FamilyRole) -> FamilyRole {
        var copy = role
        copy.title = role.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata = role.metadata
        metadata.assignmentLabel = metadata.assignmentLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if metadata.assignmentLabel.isEmpty {
            metadata.assignmentLabel = copy.title
        }
        let trimmedAnalyticsTag = metadata.analyticsTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAnalyticsTag.isEmpty {
            metadata.analyticsTag = copy.title.lowercased().replacingOccurrences(of: " ", with: "_")
        } else {
            metadata.analyticsTag = trimmedAnalyticsTag.lowercased().replacingOccurrences(of: " ", with: "_")
        }
        if let icon = metadata.iconName {
            let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata.iconName = trimmed.isEmpty ? nil : trimmed
        }
        copy.metadata = metadata
        return copy
    }

    private func makeFallbackRole(for familyID: String) -> FamilyRole {
        let timestamp = Date()
        return FamilyRole(
            id: UUID().uuidString,
            familyID: familyID,
            title: "Member",
            description: "Default household member role",
            permissions: [.manageTasks, .manageShopping],
            displayOrder: 0,
            isDefault: true,
            metadata: .init(
                assignmentLabel: "Assign to member",
                analyticsTag: "member",
                iconName: "person.fill"
            ),
            createdAt: timestamp,
            updatedAt: timestamp
        )
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
