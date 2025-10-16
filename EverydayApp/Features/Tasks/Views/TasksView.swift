import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel: TasksViewModel
    @Environment(\.appTheme) private var theme
    @State private var newTaskTitle: String = ""
    @State private var newTaskDate: Date = .now.addingTimeInterval(3600)

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
                                viewModel.toggleCompletion(for: task)
                            } label: {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(TaskFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
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
}
