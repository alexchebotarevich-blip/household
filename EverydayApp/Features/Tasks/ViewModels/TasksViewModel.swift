import Foundation
import Combine

final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var filter: TaskFilter = .active

    private let repository: TaskRepository
    private let reminderScheduler: ReminderScheduling
    private let preferencesStore: ReminderPreferencesStore
    private var cancellables = Set<AnyCancellable>()

    init(
        repository: TaskRepository = InMemoryTaskRepository.shared,
        reminderScheduler: ReminderScheduling = LocalNotificationScheduler.shared,
        preferencesStore: ReminderPreferencesStore = .shared,
        initialTasks: [TaskItem] = TaskItem.samples
    ) {
        self.repository = repository
        self.reminderScheduler = reminderScheduler
        self.preferencesStore = preferencesStore

        if !initialTasks.isEmpty {
            repository.replaceAll(initialTasks)
            initialTasks.forEach { registerAndSchedule($0) }
        }

        bind()
    }

    func addTask(title: String, dueDate: Date, assignedTo: String? = nil, type: TaskItem.Kind = .chore) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let task = TaskItem(
            title: trimmedTitle,
            dueDate: dueDate,
            assignedTo: assignedTo?.nilWhenEmpty,
            type: type
        )

        repository.add(task)
        registerAndSchedule(task)
    }

    @discardableResult
    func toggleCompletion(for task: TaskItem) -> TaskItem? {
        let updatedTask = repository.update(id: task.id) { item in
            item.isCompleted.toggle()
            if item.isCompleted {
                item.completedAt = Date()
                if item.completedBy?.isEmpty ?? true {
                    item.completedBy = item.assignedTo ?? "You"
                }
            } else {
                item.completedAt = nil
                item.completedBy = nil
            }
        }

        if let updatedTask {
            registerAndSchedule(updatedTask)
        }
        return updatedTask
    }

    private func bind() {
        repository.updates
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

    private func registerAndSchedule(_ task: TaskItem) {
        preferencesStore.register(task: task)
        if task.isCompleted {
            reminderScheduler.cancelTaskReminder(for: task.id)
        } else {
            reminderScheduler.scheduleTaskReminder(for: task)
        }
    }
}

private extension String {
    var nilWhenEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
