import Foundation

struct TaskItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var dueDate: Date
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, dueDate: Date, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}

extension TaskItem {
    static let samples: [TaskItem] = [
        TaskItem(title: "Plan weekly menu", dueDate: .now.addingTimeInterval(60 * 60 * 24)),
        TaskItem(title: "Schedule vet appointment", dueDate: .now.addingTimeInterval(60 * 60 * 48)),
        TaskItem(title: "Clean out pantry", dueDate: .now.addingTimeInterval(60 * 60 * 72))
    ]
}
