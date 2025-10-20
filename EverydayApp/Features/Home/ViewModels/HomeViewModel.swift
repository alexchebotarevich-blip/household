import Foundation
import Combine
import CombineExt

final class HomeViewModel: ObservableObject {
    enum Route: String, Identifiable {
        case history
        case analytics
        case rewards

        var id: String { rawValue }
    }

    @Published private(set) var greeting: String = "Let's plan your day"
    @Published private(set) var upcomingTasks: [TaskItem] = []
    @Published private(set) var shoppingHighlights: [ShoppingItem] = []
    @Published private(set) var insights: [HouseholdInsight] = []
    @Published private(set) var historyPreview: [HouseholdHistoryEntry] = []
    @Published private(set) var analyticsSummary: HouseholdAnalyticsSummary = .empty
    @Published var route: Route?

    private let environment: AppEnvironment
    private let taskRepository: TaskRepository
    private let shoppingRepository: ShoppingListRepository
    private let analyticsService: HouseholdAnalyticsService
    private var cancellables = Set<AnyCancellable>()

    init(
        environment: AppEnvironment = AppEnvironment(),
        taskRepository: TaskRepository = AppDependencies.taskRepository,
        shoppingRepository: ShoppingListRepository = AppDependencies.shoppingRepository,
        analyticsService: HouseholdAnalyticsService = AppDependencies.analyticsService
    ) {
        self.environment = environment
        self.taskRepository = taskRepository
        self.shoppingRepository = shoppingRepository
        self.analyticsService = analyticsService

        bindEnvironment()
        bindData()
        environment.signInIfNeeded()
    }

    func onAppear() {
        environment.signInIfNeeded()
    }

    func showHistory() {
        route = .history
    }

    func showAnalytics() {
        route = .analytics
    }

    func showRewards() {
        route = .rewards
    }

    func clearRoute() {
        route = nil
    }

    private func bindEnvironment() {
        environment.$isAuthenticated
            .removeDuplicates()
            .map { $0 ? "Welcome back" : "Let's plan your day" }
            .weakAssign(to: \HomeViewModel.greeting, on: self)
            .store(in: &cancellables)
    }

    private func bindData() {
        taskRepository.updates
            .map { tasks in
                tasks.filter { !$0.isCompleted }
                    .sorted { $0.dueDate < $1.dueDate }
            }
            .map { Array($0.prefix(3)) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.upcomingTasks = tasks
            }
            .store(in: &cancellables)

        shoppingRepository.updates
            .map { items in
                items.filter { $0.status == .pending }
                    .sorted(by: ShoppingViewModel.sortForPending)
            }
            .map { Array($0.prefix(2)) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.shoppingHighlights = items
            }
            .store(in: &cancellables)

        analyticsService.$insights
            .receive(on: DispatchQueue.main)
            .sink { [weak self] insights in
                self?.insights = Array(insights.prefix(4))
            }
            .store(in: &cancellables)

        analyticsService.$history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.historyPreview = Array(entries.prefix(5))
            }
            .store(in: &cancellables)

        analyticsService.$summary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.analyticsSummary = summary
            }
            .store(in: &cancellables)
    }
}
