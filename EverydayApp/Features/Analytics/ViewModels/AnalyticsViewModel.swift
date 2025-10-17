import Foundation
import Combine

final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var summary: HouseholdAnalyticsSummary = .empty
    @Published private(set) var dailyBreakdown: [HouseholdAnalyticsSummary.DailyBreakdown] = []
    @Published private(set) var leaderboard: [HouseholdAnalyticsSummary.LeaderboardEntry] = []

    private let analyticsService: HouseholdAnalyticsService
    private var cancellables = Set<AnyCancellable>()

    init(analyticsService: HouseholdAnalyticsService = AppDependencies.analyticsService) {
        self.analyticsService = analyticsService
        bind()
    }

    private func bind() {
        analyticsService.$summary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.summary = summary
                self?.dailyBreakdown = summary.dailyBreakdown
                self?.leaderboard = summary.leaderboard
            }
            .store(in: &cancellables)
    }
}
