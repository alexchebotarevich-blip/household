import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    @Environment(\.appTheme) private var theme

    init(viewModel: HistoryViewModel = HistoryViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            filtersSection
            entriesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.selectedMember != nil || viewModel.selectedTaskType != nil {
                    Button("Clear") {
                        viewModel.clearFilters()
                    }
                }
            }
        }
    }

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Member", selection: memberBinding) {
                ForEach(memberOptions, id: \.self) { member in
                    Text(member)
                }
            }

            Picker("Task Type", selection: taskTypeBinding) {
                Text("All").tag(TaskItem.Kind?.none)
                ForEach(viewModel.availableTaskTypes, id: \.self) { type in
                    Text(type.title).tag(TaskItem.Kind?.some(type))
                }
            }
        }
    }

    private var entriesSection: some View {
        Section("Activity") {
            if viewModel.entries.isEmpty {
                Text("No history yet. Complete tasks or log purchases to build a timeline.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .padding(.vertical, theme.spacing.small)
            } else {
                ForEach(viewModel.entries) { entry in
                    historyRow(for: entry)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, theme.spacing.xSmall)
                }
            }
        }
    }

    private var memberOptions: [String] {
        ["All"] + viewModel.members
    }

    private var memberBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.selectedMember ?? "All" },
            set: { newValue in
                viewModel.selectedMember = newValue == "All" ? nil : newValue
            }
        )
    }

    private var taskTypeBinding: Binding<TaskItem.Kind?> {
        Binding<TaskItem.Kind?>(
            get: { viewModel.selectedTaskType },
            set: { newValue in
                viewModel.selectedTaskType = newValue
            }
        )
    }

    private func historyRow(for entry: HouseholdHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            HStack(spacing: theme.spacing.small) {
                Image(systemName: iconName(for: entry))
                    .foregroundStyle(theme.colors.primary)
                Text(entry.title)
                    .font(theme.typography.body.weight(.semibold))
            }
            Text(entry.detail)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .padding(.vertical, theme.spacing.xSmall)
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
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(\.appTheme, .default)
    }
}
