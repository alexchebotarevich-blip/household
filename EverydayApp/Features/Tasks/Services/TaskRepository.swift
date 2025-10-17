import Foundation
import Combine

protocol TaskRepository {
    var updates: AnyPublisher<[TaskItem], Never> { get }

    @discardableResult
    func add(_ task: TaskItem) -> TaskItem
    @discardableResult
    func update(id: UUID, mutation: (inout TaskItem) -> Void) -> TaskItem?
    func replaceAll(_ tasks: [TaskItem])
    func task(with id: UUID) -> TaskItem?
}

final class InMemoryTaskRepository: TaskRepository {
    static let shared = InMemoryTaskRepository()

    private let queue = DispatchQueue(label: "InMemoryTaskRepository.queue", attributes: .concurrent)
    private let subject: CurrentValueSubject<[TaskItem], Never>
    private var storage: [UUID: TaskItem]

    init(initialTasks: [TaskItem] = TaskItem.samples) {
        storage = Dictionary(uniqueKeysWithValues: initialTasks.map { ($0.id, $0) })
        subject = CurrentValueSubject(Self.sort(initialTasks))
    }

    var updates: AnyPublisher<[TaskItem], Never> {
        subject
            .eraseToAnyPublisher()
    }

    @discardableResult
    func add(_ task: TaskItem) -> TaskItem {
        queue.sync(flags: .barrier) {
            storage[task.id] = task
            publishCurrent()
            return task
        }
    }

    @discardableResult
    func update(id: UUID, mutation: (inout TaskItem) -> Void) -> TaskItem? {
        queue.sync(flags: .barrier) {
            guard var existing = storage[id] else { return nil }
            mutation(&existing)
            storage[id] = existing
            publishCurrent()
            return existing
        }
    }

    func replaceAll(_ tasks: [TaskItem]) {
        queue.sync(flags: .barrier) {
            storage = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
            publishCurrent()
        }
    }

    func task(with id: UUID) -> TaskItem? {
        queue.sync {
            storage[id]
        }
    }

    private func publishCurrent() {
        let current = Self.sort(Array(storage.values))
        subject.send(current)
    }

    private static func sort(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            switch (lhs.isCompleted, rhs.isCompleted) {
            case (false, true):
                return true
            case (true, false):
                return false
            default:
                return lhs.dueDate < rhs.dueDate
            }
        }
    }
}
