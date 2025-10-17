import Foundation
import Combine

final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var filter: TaskFilter = .active

    private let allTasksSubject: CurrentValueSubject<[TaskItem], Never>
    private let reminderScheduler: ReminderScheduling
    private let preferencesStore: ReminderPreferencesStore
    private var cancellables = Set<AnyCancellable>()

    init(initialTasks: [TaskItem] = TaskItem.samples,
         reminderScheduler: ReminderScheduling = LocalNotificationScheduler.shared,
         preferencesStore: ReminderPreferencesStore = .shared) {
        self.reminderScheduler = reminderScheduler
        self.preferencesStore = preferencesStore
        self.allTasksSubject = CurrentValueSubject(initialTasks)
        initialTasks.forEach { registerAndSchedule($0) }
        bind()
    }

    func addTask(title: String, dueDate: Date) {
        let newTask = TaskItem(title: title, dueDate: dueDate)
        var updated = allTasksSubject.value
        updated.append(newTask)
        allTasksSubject.send(updated)
        registerAndSchedule(newTask)
    }

    func toggleCompletion(for task: TaskItem) {
        var updated = allTasksSubject.value
        if let index = updated.firstIndex(where: { $0.id == task.id }) {
            updated[index].isCompleted.toggle()
            allTasksSubject.send(updated)
            registerAndSchedule(updated[index])
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

    private func registerAndSchedule(_ task: TaskItem) {
        preferencesStore.register(task: task)
        if task.isCompleted {
            reminderScheduler.cancelTaskReminder(for: task.id)
        } else {
            reminderScheduler.scheduleTaskReminder(for: task)
        }
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
