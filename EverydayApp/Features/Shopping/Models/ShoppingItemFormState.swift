import Foundation

struct ShoppingItemFormState: Identifiable, Equatable {
    private(set) var identifier: UUID
    var id: UUID? {
        didSet {
            if let value = id {
                identifier = value
            }
        }
    }
    var name: String
    var quantity: Double
    var category: String
    var assignee: String
    var notes: String

    init(
        id: UUID? = nil,
        name: String = "",
        quantity: Double = 1,
        category: String = "General",
        assignee: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.identifier = id ?? UUID()
        self.name = name
        self.quantity = quantity
        self.category = category
        self.assignee = assignee
        self.notes = notes
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }
}
