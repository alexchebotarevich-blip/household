import SwiftUI

struct ReminderSettingsView: View {
    @StateObject private var viewModel: ReminderSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ReminderSettingsViewModel = ReminderSettingsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            authorizationSection
            taskSection
            shoppingSection
            quietHoursSection
        }
        .navigationTitle("Reminder Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: viewModel.quietHoursEnabled) { _ in
            viewModel.updateQuietHours()
        }
        .onChange(of: viewModel.quietHoursStart) { _ in
            viewModel.updateQuietHours()
        }
        .onChange(of: viewModel.quietHoursEnd) { _ in
            viewModel.updateQuietHours()
        }
    }

    private var authorizationSection: some View {
        Section("Notification access") {
            HStack {
                Text("Status")
                Spacer()
                Text(viewModel.description(for: viewModel.authorizationStatus))
                    .foregroundStyle(.secondary)
            }

            Button(viewModel.authorizationStatus == .authorized ? "Refresh status" : "Enable notifications") {
                Task {
                    await viewModel.requestAuthorization()
                }
            }

            if viewModel.authorizationStatus == .denied {
                Button("Open Settings", role: .none) {
                    viewModel.openSettings()
                }
            }
        }
    }

    private var taskSection: some View {
        Section("Task reminders") {
            Toggle("Enable task reminders", isOn: Binding(
                get: { viewModel.taskDefaultConfiguration.isEnabled },
                set: { viewModel.setTaskDefaultsEnabled($0) }
            ))

            Picker("Default lead time", selection: Binding(
                get: { TaskReminderConfiguration.LeadTime(rawValue: viewModel.taskDefaultConfiguration.leadTime) ?? .oneHour },
                set: { viewModel.setTaskDefaultLeadTime($0) }
            )) {
                ForEach(viewModel.leadTimeOptions, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .disabled(!viewModel.taskDefaultConfiguration.isEnabled)

            if viewModel.taskEntries.isEmpty {
                Text("Tasks will appear here as you add them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.taskEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(entry.title, isOn: Binding(
                            get: { entry.configuration.isEnabled },
                            set: { viewModel.toggleTask(entry, isEnabled: $0) }
                        ))

                        HStack {
                            Text("Due: \(entry.dueDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Lead time", selection: Binding(
                                get: { TaskReminderConfiguration.LeadTime(rawValue: entry.configuration.leadTime) ?? .oneHour },
                                set: { viewModel.updateTask(entry, leadTime: $0) }
                            )) {
                                ForEach(viewModel.leadTimeOptions, id: \.self) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(!entry.configuration.isEnabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var shoppingSection: some View {
        Section("Shopping reminders") {
            Toggle("Enable daily reminders", isOn: Binding(
                get: { viewModel.shoppingDefaultConfiguration.isEnabled },
                set: { viewModel.setShoppingDefaultsEnabled($0) }
            ))

            DatePicker("Default time", selection: Binding(
                get: { date(from: viewModel.shoppingDefaultConfiguration.remindAt) },
                set: { viewModel.setShoppingDefault(time: $0) }
            ), displayedComponents: .hourAndMinute)
            .disabled(!viewModel.shoppingDefaultConfiguration.isEnabled)

            if viewModel.shoppingEntries.isEmpty {
                Text("Lists will appear here when categories are created.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.shoppingEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(entry.title, isOn: Binding(
                            get: { entry.configuration.isEnabled },
                            set: { viewModel.toggleShopping(entry, isEnabled: $0) }
                        ))

                        DatePicker("Reminder time", selection: Binding(
                            get: { date(from: entry.configuration.remindAt) },
                            set: { viewModel.updateShopping(entry, time: $0) }
                        ), displayedComponents: .hourAndMinute)
                        .disabled(!entry.configuration.isEnabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var quietHoursSection: some View {
        Section("Quiet hours") {
            Toggle("Respect quiet hours", isOn: $viewModel.quietHoursEnabled)

            if viewModel.quietHoursEnabled {
                DatePicker("Start", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                Text("Notifications will be delayed until quiet hours end.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func date(from components: DateComponents) -> Date {
        Calendar.current.date(from: components) ?? Date()
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
}
