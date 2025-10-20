import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @Environment(\.appTheme) private var theme

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    init(viewModel: AnalyticsViewModel = AnalyticsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                summarySection
                breakdownSection
                leaderboardSection
            }
            .padding(theme.spacing.large)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Analytics")
    }

    private var summarySection: some View {
        AppFormSection(title: "Summary") {
            LazyVGrid(columns: gridColumns, spacing: theme.spacing.medium) {
                statCard(
                    icon: "checkmark.circle.fill",
                    title: "Weekly completions",
                    value: "\(viewModel.summary.weeklyCompletedCount)"
                )
                statCard(
                    icon: "clock.badge.checkmark",
                    title: "Weekly on-time",
                    value: percentageText(viewModel.summary.weeklyOnTimeRate)
                )
                statCard(
                    icon: "calendar.badge.checkmark",
                    title: "Monthly completions",
                    value: "\(viewModel.summary.monthlyCompletedCount)"
                )
                statCard(
                    icon: "chart.pie.fill",
                    title: "Monthly completion rate",
                    value: percentageText(viewModel.summary.monthlyCompletionRate)
                )
                statCard(
                    icon: "hourglass",
                    title: "Overall punctuality",
                    value: percentageText(viewModel.summary.punctualityRate)
                )
                statCard(
                    icon: "flame.fill",
                    title: "Current streak",
                    value: "\(viewModel.summary.currentStreak) days",
                    subtitle: "Best: \(viewModel.summary.longestStreak)"
                )
            }
        }
    }

    private var breakdownSection: some View {
        AppFormSection(title: "Daily breakdown") {
            if viewModel.dailyBreakdown.contains(where: { $0.completedCount > 0 }) {
                DailyBreakdownChart(breakdown: viewModel.dailyBreakdown)
                    .frame(height: 200)
            } else {
                Text("No task completions tracked this week.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .padding(.vertical, theme.spacing.small)
            }
        }
    }

    private var leaderboardSection: some View {
        AppFormSection(title: "Leaderboard") {
            let leaders = Array(viewModel.leaderboard.prefix(5))
            if leaders.isEmpty {
                Text("Complete tasks to see household rankings.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .padding(.vertical, theme.spacing.small)
            } else {
                ForEach(leaders, id: \.memberName) { entry in
                    leaderboardRow(for: entry)
                        .padding(.vertical, theme.spacing.xSmall)
                }
            }
        }
    }

    private func statCard(icon: String, title: String, value: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            HStack(spacing: theme.spacing.small) {
                Image(systemName: icon)
                    .foregroundStyle(theme.colors.primary)
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
            Text(value)
                .font(theme.typography.body.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
        }
        .padding(theme.spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private func leaderboardRow(for entry: HouseholdAnalyticsSummary.LeaderboardEntry) -> some View {
        HStack(spacing: theme.spacing.medium) {
            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text(entry.memberName)
                    .font(theme.typography.body.weight(.semibold))
                Text("\(entry.completedCount) completed • \(percentageText(entry.onTimeRate)) on time")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
            Spacer()
        }
        .padding(.vertical, theme.spacing.xSmall)
    }

    private func percentageText(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }
}

private struct DailyBreakdownChart: View {
    let breakdown: [HouseholdAnalyticsSummary.DailyBreakdown]
    @Environment(\.appTheme) private var theme

    private var maxCount: Int {
        max(breakdown.map(\.completedCount).max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(geometry.size.height - 32, 1)
            let barWidth = max(min(32, geometry.size.width / CGFloat(max(breakdown.count, 1)) / 1.5), 12)

            HStack(alignment: .bottom, spacing: theme.spacing.small) {
                ForEach(breakdown, id: \.id) { day in
                    VStack(spacing: theme.spacing.xSmall) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: theme.spacing.xSmall)
                                .fill(theme.colors.surface.opacity(0.2))
                                .frame(width: barWidth, height: availableHeight)

                            if day.completedCount > 0 {
                                RoundedRectangle(cornerRadius: theme.spacing.xSmall)
                                    .fill(theme.colors.secondary.opacity(0.35))
                                    .frame(width: barWidth, height: barHeight(for: day.completedCount, maxHeight: availableHeight))

                                RoundedRectangle(cornerRadius: theme.spacing.xSmall)
                                    .fill(theme.colors.primary)
                                    .frame(width: barWidth, height: barHeight(for: day.onTimeCount, maxHeight: availableHeight))
                            }
                        }
                        Text(label(for: day.date))
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondary)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func barHeight(for count: Int, maxHeight: CGFloat) -> CGFloat {
        guard maxCount > 0 else { return 0 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(ratio * maxHeight, count > 0 ? 4 : 0)
    }

    private func label(for date: Date) -> String {
        let formatter = DailyBreakdownChart.weekdayFormatter
        return formatter.string(from: date)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return formatter
    }()
}

#Preview {
    NavigationStack {
        AnalyticsView()
            .environment(\.appTheme, .default)
    }
}
