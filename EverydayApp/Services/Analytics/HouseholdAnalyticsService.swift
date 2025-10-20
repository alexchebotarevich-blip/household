import Foundation
import Combine

struct HouseholdHistoryEntry: Identifiable, Equatable {
    enum Source: Equatable {
        case task(TaskItem.Kind)
        case shopping
    }

    let id: UUID
    let title: String
    let detail: String
    let member: String
    let timestamp: Date
    let source: Source

    var taskType: TaskItem.Kind? {
        if case let .task(kind) = source {
            return kind
        }
        return nil
    }
}

struct HouseholdInsight: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImageName: String

    init(id: String? = nil, title: String, detail: String, systemImageName: String) {
        if let id {
            self.id = id
        } else {
            self.id = title
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
        }
        self.title = title
        self.detail = detail
        self.systemImageName = systemImageName
    }
}

struct HouseholdAnalyticsSummary: Equatable {
    struct DailyBreakdown: Identifiable, Equatable {
        let date: Date
        let completedCount: Int
        let onTimeCount: Int

        var id: Date { date }
    }

    struct LeaderboardEntry: Identifiable, Equatable {
        let memberName: String
        let completedCount: Int
        let onTimeRate: Double

        var id: String { memberName.lowercased() }
    }

    let weeklyCompletedCount: Int
    let weeklyOnTimeRate: Double
    let monthlyCompletedCount: Int
    let monthlyCompletionRate: Double
    let punctualityRate: Double
    let currentStreak: Int
    let longestStreak: Int
    let purchasesThisWeek: Int
    let leaderboard: [LeaderboardEntry]
    let dailyBreakdown: [DailyBreakdown]

    static let empty = HouseholdAnalyticsSummary(
        weeklyCompletedCount: 0,
        weeklyOnTimeRate: 0,
        monthlyCompletedCount: 0,
        monthlyCompletionRate: 0,
        punctualityRate: 0,
        currentStreak: 0,
        longestStreak: 0,
        purchasesThisWeek: 0,
        leaderboard: [],
        dailyBreakdown: []
    )
}

final class HouseholdAnalyticsService: ObservableObject {
    @Published private(set) var history: [HouseholdHistoryEntry] = []
    @Published private(set) var summary: HouseholdAnalyticsSummary = .empty
    @Published private(set) var insights: [HouseholdInsight] = []

    private var cancellables = Set<AnyCancellable>()

    init(
        taskRepository: TaskRepository,
        shoppingRepository: ShoppingListRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        let tasksPublisher = taskRepository.updates
        let activityPublisher = shoppingRepository.activityUpdates

        tasksPublisher
            .combineLatest(activityPublisher)
            .map { tasks, activities -> [HouseholdHistoryEntry] in
                HouseholdAnalyticsCalculator.makeHistory(
                    tasks: tasks,
                    activities: activities,
                    calendar: calendar,
                    now: now()
                )
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.history = entries
            }
            .store(in: &cancellables)

        tasksPublisher
            .combineLatest(activityPublisher)
            .map { tasks, activities -> HouseholdAnalyticsCalculator.SummaryResult in
                let snapshotNow = now()
                let summary = HouseholdAnalyticsCalculator.makeSummary(
                    tasks: tasks,
                    activities: activities,
                    calendar: calendar,
                    now: snapshotNow
                )
                let insights = HouseholdAnalyticsCalculator.makeInsights(
                    summary: summary,
                    tasks: tasks,
                    activities: activities,
                    now: snapshotNow,
                    calendar: calendar
                )
                return HouseholdAnalyticsCalculator.SummaryResult(summary: summary, insights: insights)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.summary = result.summary
                self?.insights = result.insights
            }
            .store(in: &cancellables)
    }
}

enum HouseholdAnalyticsCalculator {
    struct SummaryResult {
        let summary: HouseholdAnalyticsSummary
        let insights: [HouseholdInsight]
    }

    static func makeHistory(
        tasks: [TaskItem],
        activities: [ShoppingActivityLogEntry],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [HouseholdHistoryEntry] {
        var entries: [HouseholdHistoryEntry] = []
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        for task in tasks where task.isCompleted {
            guard let completedAt = task.completedAt else { continue }
            let member = task.completedBy ?? task.assignedTo ?? "Household"
            let relative = formatter.localizedString(for: completedAt, relativeTo: now)
            let status: String
            switch task.completionStatus {
            case .onTime:
                status = "On time"
            case .late:
                status = "Completed late"
            case .pending:
                status = "Completed"
            }

            entries.append(
                HouseholdHistoryEntry(
                    id: UUID(),
                    title: "\(member) completed \(task.title)",
                    detail: "\(status) • \(relative)",
                    member: member,
                    timestamp: completedAt,
                    source: .task(task.type)
                )
            )
        }

        for entry in activities where entry.action == .purchased {
            let relative = formatter.localizedString(for: entry.timestamp, relativeTo: now)
            let detail = "Qty: \(entry.quantity) • \(entry.category) • \(relative)"
            entries.append(
                HouseholdHistoryEntry(
                    id: entry.id,
                    title: entry.description,
                    detail: detail,
                    member: entry.actorName,
                    timestamp: entry.timestamp,
                    source: .shopping
                )
            )
        }

        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    static func makeSummary(
        tasks: [TaskItem],
        activities: [ShoppingActivityLogEntry],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> HouseholdAnalyticsSummary {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let monthStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        let completedTasks = tasks.filter { $0.isCompleted && $0.completedAt != nil }
        let weeklyCompleted = completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekStart
        }
        let weeklyOnTimeCount = weeklyCompleted.filter { $0.wasCompletedOnTime == true }.count
        let weeklyOnTimeRate = percentage(numerator: weeklyOnTimeCount, denominator: weeklyCompleted.count)

        let monthlyCompleted = completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= monthStart
        }

        let tasksDueThisMonth = tasks.filter { task in
            task.dueDate >= monthStart && task.dueDate <= now
        }
        let completedDueThisMonth = tasksDueThisMonth.filter { $0.isCompleted }.count
        let monthlyCompletionRate = percentage(numerator: completedDueThisMonth, denominator: tasksDueThisMonth.count)

        let punctualityOutcomes = completedTasks.compactMap { $0.wasCompletedOnTime }
        let punctualityRate = percentage(
            numerator: punctualityOutcomes.filter { $0 }.count,
            denominator: punctualityOutcomes.count
        )

        let streaks = computeStreaks(from: completedTasks.compactMap { $0.completedAt }, calendar: calendar, today: today)
        let purchasesThisWeek = activities.filter { $0.action == .purchased && $0.timestamp >= weekStart }.count
        let leaderboard = makeLeaderboard(from: completedTasks)
        let dailyBreakdown = makeDailyBreakdown(from: completedTasks, calendar: calendar, today: today)

        return HouseholdAnalyticsSummary(
            weeklyCompletedCount: weeklyCompleted.count,
            weeklyOnTimeRate: weeklyOnTimeRate,
            monthlyCompletedCount: monthlyCompleted.count,
            monthlyCompletionRate: monthlyCompletionRate,
            punctualityRate: punctualityRate,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            purchasesThisWeek: purchasesThisWeek,
            leaderboard: leaderboard,
            dailyBreakdown: dailyBreakdown
        )
    }

    static func makeInsights(
        summary: HouseholdAnalyticsSummary,
        tasks: [TaskItem],
        activities: [ShoppingActivityLogEntry],
        now: Date,
        calendar: Calendar
    ) -> [HouseholdInsight] {
        var insights: [HouseholdInsight] = []

        if summary.weeklyCompletedCount > 0 {
            let percentageText = Self.percentageText(from: summary.weeklyOnTimeRate)
            insights.append(
                HouseholdInsight(
                    id: "on-time",
                    title: "On-time completions",
                    detail: "\(percentageText) of tasks were finished on time this week.",
                    systemImageName: "clock.badge.checkmark"
                )
            )
        } else {
            insights.append(
                HouseholdInsight(
                    id: "on-time",
                    title: "On-time completions",
                    detail: "Complete a task to start tracking punctuality.",
                    systemImageName: "clock"
                )
            )
        }

        if let top = summary.leaderboard.first {
            let leaderRate = Self.percentageText(from: top.onTimeRate)
            let countText = top.completedCount == 1 ? "task" : "tasks"
            insights.append(
                HouseholdInsight(
                    id: "top-contributor",
                    title: "Top contributor",
                    detail: "\(top.memberName) completed \(top.completedCount) \(countText) with \(leaderRate) on time.",
                    systemImageName: "person.fill.checkmark"
                )
            )
        } else {
            insights.append(
                HouseholdInsight(
                    id: "top-contributor",
                    title: "Top contributor",
                    detail: "Assign members to tasks to populate the leaderboard.",
                    systemImageName: "person"
                )
            )
        }

        if summary.currentStreak > 0 {
            let detail = "\(summary.currentStreak)-day streak (best: \(summary.longestStreak) days)."
            insights.append(
                HouseholdInsight(
                    id: "streak",
                    title: "Completion streak",
                    detail: detail,
                    systemImageName: "flame.fill"
                )
            )
        } else {
            insights.append(
                HouseholdInsight(
                    id: "streak",
                    title: "Completion streak",
                    detail: "No active streak yet. Complete a task today to get started.",
                    systemImageName: "flame"
                )
            )
        }

        if summary.purchasesThisWeek > 0 {
            let countText = summary.purchasesThisWeek == 1 ? "purchase" : "purchases"
            insights.append(
                HouseholdInsight(
                    id: "shopping",
                    title: "Shopping wins",
                    detail: "\(summary.purchasesThisWeek) \(countText) logged this week.",
                    systemImageName: "cart.fill.badge.plus"
                )
            )
        } else {
            insights.append(
                HouseholdInsight(
                    id: "shopping",
                    title: "Shopping wins",
                    detail: "No shopping checkouts recorded this week.",
                    systemImageName: "cart"
                )
            )
        }

        return Array(insights.prefix(4))
    }

    private static func makeLeaderboard(from tasks: [TaskItem]) -> [HouseholdAnalyticsSummary.LeaderboardEntry] {
        let grouped = Dictionary(grouping: tasks) { task -> String in
            task.completedBy ?? task.assignedTo ?? "Household"
        }

        return grouped.map { member, tasks in
            let onTimeCount = tasks.filter { $0.wasCompletedOnTime == true }.count
            let rate = percentage(numerator: onTimeCount, denominator: tasks.count)
            return HouseholdAnalyticsSummary.LeaderboardEntry(
                memberName: member,
                completedCount: tasks.count,
                onTimeRate: rate
            )
        }
        .sorted { lhs, rhs in
            if lhs.completedCount == rhs.completedCount {
                return lhs.memberName.localizedCaseInsensitiveCompare(rhs.memberName) == .orderedAscending
            }
            return lhs.completedCount > rhs.completedCount
        }
    }

    private static func makeDailyBreakdown(
        from tasks: [TaskItem],
        calendar: Calendar,
        today: Date
    ) -> [HouseholdAnalyticsSummary.DailyBreakdown] {
        var breakdown: [HouseholdAnalyticsSummary.DailyBreakdown] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayTasks = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= dayStart && completedAt < nextDay
            }
            let onTimeCount = dayTasks.filter { $0.wasCompletedOnTime == true }.count
            breakdown.append(
                HouseholdAnalyticsSummary.DailyBreakdown(
                    date: dayStart,
                    completedCount: dayTasks.count,
                    onTimeCount: onTimeCount
                )
            )
        }
        return breakdown
    }

    private static func computeStreaks(
        from completionDates: [Date],
        calendar: Calendar,
        today: Date
    ) -> (current: Int, longest: Int) {
        guard !completionDates.isEmpty else { return (0, 0) }
        let uniqueDays = Set(completionDates.map { calendar.startOfDay(for: $0) })
        let sortedDays = uniqueDays.sorted()

        var longest = 0
        var currentRun = 0
        var previousDay: Date?

        for day in sortedDays {
            if let previous = previousDay,
               let diff = calendar.dateComponents([.day], from: previous, to: day).day,
               diff == 1 {
                currentRun += 1
            } else {
                currentRun = 1
            }
            longest = max(longest, currentRun)
            previousDay = day
        }

        var currentStreak = 0
        if let latestDay = sortedDays.last {
            var cursor = latestDay
            while uniqueDays.contains(cursor) {
                currentStreak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }

            if let gap = calendar.dateComponents([.day], from: latestDay, to: today).day, gap > 1 {
                currentStreak = 0
            }
        }

        return (current: currentStreak, longest: longest)
    }

    private static func percentage(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private static func percentageText(from value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }
}
