import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var router: AppRouter
    @State private var rewardMessage: String?

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    header
                    insightsSection
                    analyticsSummarySection
                    upcomingTasksSection
                    historySection
                    shoppingHighlightsSection
                }
                .padding(theme.spacing.large)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationDestination(item: $viewModel.route) { destination in
                destinationView(for: destination)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.showHistory()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }

                    Button {
                        viewModel.showAnalytics()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
        .onReceive(router.$pendingRewardMessage.removeDuplicates()) { message in
            guard let message else { return }
            rewardMessage = message
            router.pendingRewardMessage = nil
        }
        .alert(rewardMessage ?? "", isPresented: Binding(
            get: { rewardMessage != nil },
            set: { isPresented in
                if !isPresented {
                    rewardMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(viewModel.greeting)
                .font(theme.typography.title)
            Text("Here's what's coming up for your household")
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.colors.secondary)
        }
    }

    private var insightsSection: some View {
        AppFormSection(title: "Insights") {
            if viewModel.insights.isEmpty {
                emptyState(text: "Insights will appear once activity starts.")
            } else {
                ForEach(viewModel.insights) { insight in
                    insightCard(for: insight)
                }
                PrimaryButton(title: "Open Analytics", icon: "chart.bar.doc.horizontal.fill") {
                    viewModel.showAnalytics()
                }
            }
        }
    }

    private var analyticsSummarySection: some View {
        AppFormSection(title: "This Week") {
            analyticsMetric(
                icon: "checkmark.circle.fill",
                title: "Tasks completed",
                value: "\(viewModel.analyticsSummary.weeklyCompletedCount)"
            )
            analyticsMetric(
                icon: "clock.badge.checkmark",
                title: "On-time rate",
                value: percentageText(viewModel.analyticsSummary.weeklyOnTimeRate)
            )
            analyticsMetric(
                icon: "cart.fill",
                title: "Purchases",
                value: "\(viewModel.analyticsSummary.purchasesThisWeek)"
            )
        }
    }

    private var upcomingTasksSection: some View {
        AppFormSection(title: "Upcoming Tasks") {
            ForEach(viewModel.upcomingTasks) { task in
                AppListRow(
                    title: task.title,
                    subtitle: task.dueDate.formatted(date: .abbreviated, time: .omitted)
                ) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? theme.colors.primary : theme.colors.secondary)
                }
            }

            if viewModel.upcomingTasks.isEmpty {
                emptyState(text: "No tasks queued. Add one to get started.")
            }
        }
    }

    private var historySection: some View {
        AppFormSection(title: "Recent Activity") {
            ForEach(viewModel.historyPreview) { entry in
                historyRow(for: entry)
            }

            if viewModel.historyPreview.isEmpty {
                emptyState(text: "Complete tasks or log purchases to see history.")
            }

            PrimaryButton(title: "View History", icon: "clock.arrow.circlepath") {
                viewModel.showHistory()
            }
        }
    }

    private var shoppingHighlightsSection: some View {
        AppFormSection(title: "Shopping List") {
            ForEach(viewModel.shoppingHighlights) { item in
                AppListRow(title: item.name, subtitle: item.detailSummary) {
                    if let notes = item.notes {
                        Text(notes)
                    } else {
                        Image(systemName: "chevron.right")
                    }
                }
            }

            if viewModel.shoppingHighlights.isEmpty {
                emptyState(text: "You have everything you need.")
            }

            PrimaryButton(title: "View Full List", icon: "cart") {}
        }
    }

    @ViewBuilder
    private func destinationView(for route: HomeViewModel.Route) -> some View {
        switch route {
        case .history:
            HistoryView()
        case .analytics:
            AnalyticsView()
        }
    }

    private func insightCard(for insight: HouseholdInsight) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.medium) {
            Image(systemName: insight.systemImageName)
                .foregroundStyle(theme.colors.primary)
                .font(.system(size: 28))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text(insight.title)
                    .font(theme.typography.body)
                    .fontWeight(.semibold)
                Text(insight.detail)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private func analyticsMetric(icon: String, title: String, value: String) -> some View {
        HStack(spacing: theme.spacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(theme.colors.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                Text(value)
                    .font(theme.typography.body.weight(.semibold))
            }
            Spacer()
        }
        .padding(.vertical, theme.spacing.xSmall)
    }

    private func historyRow(for entry: HouseholdHistoryEntry) -> some View {
        AppListRow(title: entry.title, subtitle: entry.detail) {
            Image(systemName: iconName(for: entry))
                .foregroundStyle(theme.colors.primary)
        }
    }

    private func iconName(for entry: HouseholdHistoryEntry) -> String {
        switch entry.source {
        case .task(let kind):
            switch kind {
            case .chore:
                return "checkmark.circle"
            case .errand:
                return "car"
            case .appointment:
                return "calendar"
            case .celebration:
                return "party.popper"
            case .maintenance:
                return "wrench"
            }
        case .shopping:
            return "cart.fill"
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.secondary.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.spacing.medium)
            .padding(.vertical, theme.spacing.small)
            .background(theme.colors.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private func percentageText(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }
}

#Preview {
    HomeView()
        .environment(\.appTheme, .default)
        .environmentObject(AppRouter())
}
