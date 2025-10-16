import Foundation

struct TaskReminderConfiguration: Codable, Equatable {
    enum LeadTime: TimeInterval, CaseIterable {
        case fifteenMinutes = 900
        case thirtyMinutes = 1_800
        case oneHour = 3_600
        case twoHours = 7_200
        case oneDay = 86_400
        case custom = -1

        var title: String {
            switch self {
            case .fifteenMinutes:
                return "15 minutes before"
            case .thirtyMinutes:
                return "30 minutes before"
            case .oneHour:
                return "1 hour before"
            case .twoHours:
                return "2 hours before"
            case .oneDay:
                return "1 day before"
            case .custom:
                return "Custom"
            }
        }
    }

    var isEnabled: Bool
    var leadTime: TimeInterval

    init(isEnabled: Bool = true, leadTime: TimeInterval = LeadTime.oneHour.rawValue) {
        self.isEnabled = isEnabled
        self.leadTime = leadTime
    }

    var leadTimeComponent: LeadTime {
        LeadTime(rawValue: leadTime) ?? .custom
    }
}

struct ShoppingReminderConfiguration: Codable, Equatable {
    var isEnabled: Bool
    /// Hour/minute for the reminder. Weekday is optional and only applied when `weekdays` is not empty.
    var remindAt: DateComponents
    /// Weekday numbers using Calendar component: Sunday = 1 ... Saturday = 7.
    var weekdays: Set<Int>

    init(isEnabled: Bool = true,
         remindAt: DateComponents = DateComponents(hour: 18, minute: 0),
         weekdays: Set<Int> = []) {
        self.isEnabled = isEnabled
        self.remindAt = remindAt
        self.weekdays = weekdays
    }
}

struct QuietHoursConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var start: DateComponents
    var end: DateComponents

    init(isEnabled: Bool = false,
         start: DateComponents = DateComponents(hour: 22, minute: 0),
         end: DateComponents = DateComponents(hour: 7, minute: 0)) {
        self.isEnabled = isEnabled
        self.start = start
        self.end = end
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        guard let startDate = calendar.converting(components: start, matching: date),
              let endDate = calendar.converting(components: end, matching: date) else {
            return false
        }

        if startDate <= endDate {
            return date >= startDate && date < endDate
        } else {
            // Quiet hours wrap across midnight.
            return date >= startDate || date < calendar.date(byAdding: .day, value: 1, to: endDate)!
        }
    }

    func nextAvailableDate(after date: Date, calendar: Calendar = .current) -> Date {
        guard isEnabled else { return date }
        guard contains(date, calendar: calendar) else { return date }
        guard var endDate = calendar.converting(components: end, matching: date) else {
            return date
        }
        if endDate <= date {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? date
        }
        return endDate
    }
}

struct ReminderPreferences: Codable, Equatable {
    struct TaskEntry: Codable, Equatable, Identifiable {
        let id: UUID
        var title: String
        var dueDate: Date
        var configuration: TaskReminderConfiguration

        init(id: UUID, title: String, dueDate: Date, configuration: TaskReminderConfiguration = TaskReminderConfiguration()) {
            self.id = id
            self.title = title
            self.dueDate = dueDate
            self.configuration = configuration
        }
    }

    struct ShoppingEntry: Codable, Equatable, Identifiable {
        let id: String
        var title: String
        var configuration: ShoppingReminderConfiguration

        init(id: String, title: String, configuration: ShoppingReminderConfiguration = ShoppingReminderConfiguration()) {
            self.id = id
            self.title = title
            self.configuration = configuration
        }
    }

    var taskDefaults: TaskReminderConfiguration
    var shoppingDefaults: ShoppingReminderConfiguration
    var quietHours: QuietHoursConfiguration?
    var tasks: [TaskEntry]
    var shoppingLists: [ShoppingEntry]

    init(taskDefaults: TaskReminderConfiguration = TaskReminderConfiguration(),
         shoppingDefaults: ShoppingReminderConfiguration = ShoppingReminderConfiguration(),
         quietHours: QuietHoursConfiguration? = QuietHoursConfiguration(),
         tasks: [TaskEntry] = [],
         shoppingLists: [ShoppingEntry] = []) {
        self.taskDefaults = taskDefaults
        self.shoppingDefaults = shoppingDefaults
        self.quietHours = quietHours
        self.tasks = tasks
        self.shoppingLists = shoppingLists
    }

    static var `default`: ReminderPreferences {
        ReminderPreferences()
    }

    func taskEntry(with id: UUID) -> TaskEntry? {
        tasks.first(where: { $0.id == id })
    }

    func shoppingEntry(with id: String) -> ShoppingEntry? {
        shoppingLists.first(where: { $0.id == id })
    }

    mutating func upsertTask(_ task: TaskEntry) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    mutating func updateTask(id: UUID, transform: (inout TaskEntry) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        transform(&tasks[index])
    }

    mutating func upsertShoppingList(_ list: ShoppingEntry) {
        if let index = shoppingLists.firstIndex(where: { $0.id == list.id }) {
            shoppingLists[index] = list
        } else {
            shoppingLists.append(list)
        }
    }

    mutating func updateShoppingList(id: String, transform: (inout ShoppingEntry) -> Void) {
        guard let index = shoppingLists.firstIndex(where: { $0.id == id }) else { return }
        transform(&shoppingLists[index])
    }
}

private extension Calendar {
    func converting(components: DateComponents, matching referenceDate: Date) -> Date? {
        var referenceComponents = dateComponents([.year, .month, .day, .hour, .minute, .second], from: referenceDate)
        referenceComponents.hour = components.hour
        referenceComponents.minute = components.minute
        referenceComponents.second = components.second ?? 0
        return date(from: referenceComponents)
    }
}
