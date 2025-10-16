import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.appTheme) private var theme

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.large) {
                header
                upcomingTasksSection
                shoppingHighlightsSection
            }
            .padding(theme.spacing.large)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .onAppear {
            viewModel.onAppear()
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

    private var upcomingTasksSection: some View {
        AppFormSection(title: "Upcoming Tasks") {
            ForEach(viewModel.upcomingTasks) { task in
                AppListRow(title: task.title, subtitle: task.dueDate.formatted(date: .abbreviated, time: .omitted)) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? theme.colors.primary : theme.colors.secondary)
                }
            }

            if viewModel.upcomingTasks.isEmpty {
                emptyState(text: "No tasks queued. Add one to get started.")
            }
        }
    }

    private var shoppingHighlightsSection: some View {
        AppFormSection(title: "Shopping List") {
            ForEach(viewModel.shoppingHighlights) { item in
                AppListRow(title: item.name, subtitle: "Quantity: \(item.quantity)") {
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
}

#Preview {
    HomeView()
        .environment(\.appTheme, .default)
}
