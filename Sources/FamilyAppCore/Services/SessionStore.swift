import Foundation

public enum SessionState: Equatable, Sendable {
    case loggedOut
    case awaitingFamily(user: User)
    case active(user: User, family: Family)
}

public actor SessionStore {
    private var state: SessionState = .loggedOut
    private var continuations: [UUID: AsyncStream<SessionState>.Continuation] = [:]

    public init() {}

    public func update(_ newState: SessionState) {
        state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }

    public func currentState() -> SessionState {
        state
    }

    public func updates() -> AsyncStream<SessionState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.yield(state)
            continuations[id] = continuation
        } onTermination: { _ in
            Task {
                await self.removeContinuation(id: id)
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
