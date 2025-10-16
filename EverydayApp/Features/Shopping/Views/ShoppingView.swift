import SwiftUI

struct ShoppingView: View {
    @StateObject private var viewModel: ShoppingViewModel
    @Environment(\.appTheme) private var theme
    @State private var formState: ShoppingItemFormState = ShoppingItemFormState()
    @State private var isPresentingForm: Bool = false
    @State private var isEditing: Bool = false

    init(viewModel: ShoppingViewModel = ShoppingViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                pendingSection
                purchasedSection
                historySection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.colors.background)
            .overlay {
                if viewModel.pendingItems.isEmpty && viewModel.purchasedItems.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Shopping")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentForm(for: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $isPresentingForm) {
                ShoppingItemFormView(
                    formState: $formState,
                    categories: viewModel.availableCategories,
                    isEditing: isEditing,
                    onSave: { state in
                        viewModel.save(form: state)
                        dismissForm()
                    },
                    onCancel: dismissForm
                )
            }
            .alert(item: $viewModel.undoPrompt) { prompt in
                Alert(
                    title: Text(prompt.title),
                    message: Text(prompt.message),
                    primaryButton: .default(Text("Undo"), action: prompt.onUndo),
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var pendingSection: some View {
        Section(header: Text("Pending")) {
            if viewModel.pendingItems.isEmpty {
                Text("Nothing pending. Add something to pick up at the store.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            } else {
                ForEach(viewModel.pendingItems) { item in
                    ShoppingListRow(
                        title: item.name,
                        subtitle: item.detailSummary,
                        accessory: {
                            Button {
                                viewModel.togglePurchased(for: item)
                            } label: {
                                Image(systemName: "cart.badge.checkmark")
                                    .foregroundStyle(theme.colors.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mark as purchased")
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { presentForm(for: item) }
                    .swipeActions(edge: .trailing) {
                        Button("Purchased") {
                            viewModel.togglePurchased(for: item)
                        }
                        .tint(.green)

                        Button("Edit") {
                            presentForm(for: item)
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            viewModel.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .textCase(nil)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var purchasedSection: some View {
        Section(header: Text("Purchased")) {
            if viewModel.purchasedItems.isEmpty {
                Text("Purchased items will appear here with attribution.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            } else {
                ForEach(viewModel.purchasedItems) { item in
                    ShoppingListRow(
                        title: item.name,
                        subtitle: item.purchasedSummary ?? item.detailSummary,
                        accessory: {
                            Button {
                                viewModel.togglePurchased(for: item)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundStyle(theme.colors.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mark as pending")
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { presentForm(for: item) }
                    .swipeActions(edge: .trailing) {
                        Button("Unmark") {
                            viewModel.togglePurchased(for: item)
                        }
                        .tint(.orange)

                        Button(role: .destructive) {
                            viewModel.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .textCase(nil)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var historySection: some View {
        Section(header: Text("Purchase history")) {
            if viewModel.purchaseHistory.isEmpty {
                Text("Track who picked up items and when.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            } else {
                ForEach(viewModel.purchaseHistory) { entry in
                    ShoppingListRow(
                        title: entry.description,
                        subtitle: entry.detailSummary,
                        accessory: { EmptyView() }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .textCase(nil)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.medium) {
            Image(systemName: "cart")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(theme.colors.secondary)
            Text("Your shared shopping list is empty.")
                .font(theme.typography.subtitle)
            Text("Add items to start collaborating in real time.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(theme.spacing.large)
    }

    private func presentForm(for item: ShoppingItem?) {
        if let item {
            formState = viewModel.formState(for: item)
            isEditing = true
        } else {
            formState = viewModel.makeNewFormState()
            isEditing = false
        }
        isPresentingForm = true
    }

    private func dismissForm() {
        isPresentingForm = false
    }
}

private struct ShoppingListRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: () -> Accessory
    @Environment(\.appTheme) private var theme

    var body: some View {
        AppListRow(title: title, subtitle: subtitle) {
            accessory()
        }
        .padding(.vertical, theme.spacing.xSmall)
    }
}

struct ShoppingItemFormView: View {
    @Binding var formState: ShoppingItemFormState
    let categories: [String]
    let isEditing: Bool
    let onSave: (ShoppingItemFormState) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Item name", text: $formState.name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    Stepper(value: $formState.quantity, in: 1...50, step: 1) {
                        Text("Quantity: \(Int(formState.quantity.rounded()))")
                    }
                    TextField("Category", text: $formState.category)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Assignments")) {
                    TextField("Assign to", text: $formState.assignee)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Notes", text: $formState.notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if !categories.isEmpty {
                    Section(header: Text("Suggestions")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: theme.spacing.small) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        formState.category = category
                                    } label: {
                                        Text(category)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(formState.category == category ? theme.colors.primary.opacity(0.15) : theme.colors.surface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, theme.spacing.xSmall)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit item" : "Add item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        onSave(formState)
                    }
                    .disabled(!formState.isValid)
                }
            }
        }
    }
}

#Preview {
    ShoppingView()
        .environment(\.appTheme, .default)
}
