import SwiftUI

struct ShoppingView: View {
    @StateObject private var viewModel: ShoppingViewModel
    @Environment(\.appTheme) private var theme
    @State private var newItemName: String = ""
    @State private var quantity: Int = 1
    @State private var notes: String = ""

    init(viewModel: ShoppingViewModel = ShoppingViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.large) {
                    AppFormSection(title: "Your list") {
                        ForEach(viewModel.items) { item in
                            AppListRow(title: item.name, subtitle: "Qty: \(item.quantity)") {
                                if let notes = item.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.secondary)
                                } else {
                                    EmptyView()
                                }
                            }
                        }

                        if viewModel.items.isEmpty {
                            Text("Add the first item to begin planning your shop.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.secondary)
                        }
                    }

                    AppFormSection(title: "Add item") {
                        TextField("Name", text: $newItemName)
                            .textFieldStyle(.roundedBorder)
                        Stepper(value: $quantity, in: 1...20) {
                            Text("Quantity: \(quantity)")
                                .font(theme.typography.body)
                        }
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                        PrimaryButton(title: "Add", icon: "cart.badge.plus") {
                            guard !newItemName.isEmpty else { return }
                            viewModel.addItem(name: newItemName, quantity: quantity, notes: notes.isEmpty ? nil : notes)
                            newItemName = ""
                            quantity = 1
                            notes = ""
                        }
                    }
                }
                .padding(theme.spacing.large)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Shopping")
        }
    }
}

#Preview {
    ShoppingView()
        .environment(\.appTheme, .default)
}
