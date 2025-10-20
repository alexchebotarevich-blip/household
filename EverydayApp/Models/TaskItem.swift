import Foundation

struct TaskItem: Identifiable, Codable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case chore
        case errand
        case appointment
        case celebration
        case maintenance

        var id: String { rawValue }

        var title: String {
            switch self {
            case .chore:
                return "Chore"
            case .errand:
                return "Errand"
            case .appointment:
                return "Appointment"
            case .celebration:
                return "Celebration"
            case .maintenance:
                return "Maintenance"
            }
        }
    }

    enum CompletionStatus: String, Codable {
        case pending
        case onTime
        case late
    }

    let id: UUID
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    var assignedTo: String?
    var completedBy: String?
    var completedAt: Date?
    var type: Kind

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date,
        isCompleted: Bool = false,
        assignedTo: String? = nil,
        completedBy: String? = nil,
        completedAt: Date? = nil,
        type: Kind = .chore
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.assignedTo = assignedTo
        self.completedBy = completedBy
        self.completedAt = completedAt
        self.type = type
    }

    var completionStatus: CompletionStatus {
        guard isCompleted, let completedAt else { return .pending }
        if completedAt <= dueDate {
            return .onTime
        }
        return .late
    }

    var wasCompletedOnTime: Bool? {
        guard isCompleted else { return nil }
        return completionStatus == .onTime
    }
}

extension TaskItem {
    static let samples: [TaskItem] = [
        TaskItem(
            title: "Plan weekly menu",
            dueDate: Date().addingTimeInterval(60 * 60 * 24),
            assignedTo: "Alex",
            type: .chore
        ),
        TaskItem(
            title: "Schedule vet appointment",
            dueDate: Date().addingTimeInterval(60 * 60 * 36),
            isCompleted: true,
            assignedTo: "Jamie",
            completedBy: "Jamie",
            completedAt: Date().addingTimeInterval(-60 * 60),
            type: .errand
        ),
        TaskItem(
            title: "Clean out pantry",
            dueDate: Date().addingTimeInterval(-60 * 60 * 48),
            isCompleted: true,
            assignedTo: "Alex",
            completedBy: "Alex",
            completedAt: Date().addingTimeInterval(-60 * 60 * 12),
            type: .maintenance
        ),
        TaskItem(
            title: "Birthday decorations",
            dueDate: Date().addingTimeInterval(60 * 60 * 72),
            assignedTo: "Taylor",
            type: .celebration
        )
    ]
}
