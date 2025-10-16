import Foundation
import Combine

final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var filter: TaskFilter = .active

    private let allTasksSubject: CurrentValueSubject<[TaskItem], Never>
    private var cancellables = Set<AnyCancellable>()

    init(initialTasks: [TaskItem] = TaskItem.samples) {
        allTasksSubject = CurrentValueSubject(initialTasks)
        bind()
    }

    func addTask(title: String, dueDate: Date) {
        var updated = allTasksSubject.value
        updated.append(TaskItem(title: title, dueDate: dueDate))
        allTasksSubject.send(updated)
    }

    func toggleCompletion(for task: TaskItem) {
        var updated = allTasksSubject.value
        if let index = updated.firstIndex(where: { $0.id == task.id }) {
            updated[index].isCompleted.toggle()
            allTasksSubject.send(updated)
        }
    }

    private func bind() {
        allTasksSubject
            .combineLatest($filter.removeDuplicates())
            .map { tasks, filter in
                switch filter {
                case .active:
                    return tasks.filter { !$0.isCompleted }
                case .completed:
                    return tasks.filter { $0.isCompleted }
                case .all:
                    return tasks
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.tasks = tasks
            }
            .store(in: &cancellables)
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case active
    case completed
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .all: return "All"
        }
    }
}
