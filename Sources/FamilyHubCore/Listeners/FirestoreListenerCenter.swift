import Foundation

public protocol Cancellable {
    func cancel()
}

public struct FirestoreCollectionDescriptor: Hashable, Sendable {
    public let collection: FirestoreCollection
    public let scopeIdentifier: String?

    public init(collection: FirestoreCollection, scopeIdentifier: String? = nil) {
        self.collection = collection
        self.scopeIdentifier = scopeIdentifier
    }

    public var path: String {
        guard let scopeIdentifier else { return collection.path }
        return "\(collection.path)/\(scopeIdentifier)"
    }
}

public enum FirestoreListenerEvent<Entity: FirestoreEntity>: Equatable, Sendable {
    case added(Entity)
    case modified(Entity)
    case removed(Entity)
}

public struct FirestoreListenerToken: Cancellable, Hashable, Sendable {
    fileprivate let id: UUID
    private let cancelHandler: @Sendable () -> Void

    public init(id: UUID = UUID(), cancelHandler: @escaping @Sendable () -> Void) {
        self.id = id
        self.cancelHandler = cancelHandler
    }

    public func cancel() {
        cancelHandler()
    }
}

public protocol FirestoreListening: AnyObject {
    @discardableResult
    func listen<Entity: FirestoreEntity>(
        to descriptor: FirestoreCollectionDescriptor,
        as type: Entity.Type,
        onEvent: @escaping @Sendable (Result<[FirestoreListenerEvent<Entity>], Error>) -> Void
    ) -> FirestoreListenerToken

    func removeListener(_ token: FirestoreListenerToken)
}

public final class FirestoreListenerCenter: FirestoreListening {
    private struct ListenerBox {
        let id: UUID
        let descriptor: FirestoreCollectionDescriptor
        let typeIdentifier: ObjectIdentifier
        let handler: @Sendable (Result<[Any], Error>) -> Void
    }

    private let storageQueue = DispatchQueue(label: "FirestoreListenerCenter.storage", attributes: .concurrent)
    private let deliveryQueue: DispatchQueue
    private var listeners: [UUID: ListenerBox] = [:]

    public init(deliveryQueue: DispatchQueue = .main) {
        self.deliveryQueue = deliveryQueue
    }

    @discardableResult
    public func listen<Entity: FirestoreEntity>(
        to descriptor: FirestoreCollectionDescriptor,
        as type: Entity.Type,
        onEvent: @escaping @Sendable (Result<[FirestoreListenerEvent<Entity>], Error>) -> Void
    ) -> FirestoreListenerToken {
        let identifier = UUID()

        let box = ListenerBox(
            id: identifier,
            descriptor: descriptor,
            typeIdentifier: ObjectIdentifier(type)
        ) { result in
            switch result {
            case .success(let anyEvents):
                guard let typedEvents = anyEvents as? [FirestoreListenerEvent<Entity>] else { return }
                onEvent(.success(typedEvents))
            case .failure(let error):
                onEvent(.failure(error))
            }
        }

        storageQueue.async(flags: .barrier) {
            self.listeners[identifier] = box
        }

        return FirestoreListenerToken(id: identifier) { [weak self] in
            self?.removeListener(with: identifier)
        }
    }

    public func removeListener(_ token: FirestoreListenerToken) {
        removeListener(with: token.id)
    }

    public func publish<Entity: FirestoreEntity>(
        _ events: [FirestoreListenerEvent<Entity>],
        for descriptor: FirestoreCollectionDescriptor
    ) {
        broadcast(.success(events), for: descriptor, entity: Entity.self)
    }

    public func publishError<Entity: FirestoreEntity>(
        _ error: Error,
        for descriptor: FirestoreCollectionDescriptor,
        entity: Entity.Type
    ) {
        broadcast(.failure(error), for: descriptor, entity: entity)
    }

    private func broadcast<Entity: FirestoreEntity>(
        _ result: Result<[FirestoreListenerEvent<Entity>], Error>,
        for descriptor: FirestoreCollectionDescriptor,
        entity: Entity.Type
    ) {
        var matchingListeners: [ListenerBox] = []

        storageQueue.sync {
            matchingListeners = listeners.values.filter { box in
                box.descriptor == descriptor && box.typeIdentifier == ObjectIdentifier(entity)
            }
        }

        guard !matchingListeners.isEmpty else { return }

        deliveryQueue.async {
            let erasedResult = result.map { $0.map { $0 as Any } }
            for listener in matchingListeners {
                listener.handler(erasedResult)
            }
        }
    }

    private func removeListener(with identifier: UUID) {
        storageQueue.async(flags: .barrier) {
            self.listeners.removeValue(forKey: identifier)
        }
    }
}
