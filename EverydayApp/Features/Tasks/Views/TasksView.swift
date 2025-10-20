import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel: TasksViewModel
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var router: AppRouter
    @State private var newTaskTitle: String = ""
    @State private var newTaskDate: Date = .now.addingTimeInterval(3600)
    @State private var highlightedTaskID: UUID?

    init(viewModel: TasksViewModel = TasksViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.medium) {
                filterPicker
                List {
                    ForEach(viewModel.tasks) { task in
                        AppListRow(title: task.title,
                                   subtitle: task.dueDate.formatted(date: .abbreviated, time: .shortened)) {
                            Button {
                                if let updated = viewModel.toggleCompletion(for: task), updated.isCompleted,
                                   let result = GamificationEngine.shared.processTaskCompletion(updated) {
                                    router.pendingRewardMessage = result.message
                                }
                            } label: {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)

                        .padding(.vertical, theme.spacing.xSmall)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .background(highlightBackground(for: task.id))
                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.tasks.isEmpty {
                        emptyState
                    }
                }

                AppFormSection(title: "Create Task") {
                    TextField("Task title", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("Due", selection: $newTaskDate, displayedComponents: [.date, .hourAndMinute])
                    PrimaryButton(title: "Add Task", icon: "plus") {
                        guard !newTaskTitle.isEmpty else { return }
                        viewModel.addTask(title: newTaskTitle, dueDate: newTaskDate)
                        newTaskTitle = ""
                        newTaskDate = .now.addingTimeInterval(3600)
                    }
                }
            }
            .padding(theme.spacing.medium)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Tasks")
        }
        .onReceive(router.$highlightedTaskID.removeDuplicates()) { taskID in
            highlightedTaskID = taskID
            if taskID != nil {
                router.clearTaskHighlight()
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    if highlightedTaskID == taskID {
                        highlightedTaskID = nil
                    }
                }
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(TaskFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private func highlightBackground(for taskID: UUID) -> some View {
        Group {
            if highlightedTaskID == taskID {
                theme.colors.primary.opacity(0.18)
            } else {
                Color.clear
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.small) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 42))
                .foregroundStyle(theme.colors.secondary)
            Text("Nothing to do yet. Create a task to get organised.")
                .multilineTextAlignment(.center)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.secondary)
        }
        .padding(theme.spacing.large)
    }
}

#Preview {
    TasksView()
        .environment(\.appTheme, .default)
        .environmentObject(AppRouter())
}
