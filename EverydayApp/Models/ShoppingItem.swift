import Foundation

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Int
    var notes: String?

    init(id: UUID = UUID(), name: String, quantity: Int = 1, notes: String? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.notes = notes
    }
}

extension ShoppingItem {
    static let samples: [ShoppingItem] = [
        ShoppingItem(name: "Oat Milk", quantity: 2),
        ShoppingItem(name: "Blueberries", quantity: 1, notes: "Organic if available"),
        ShoppingItem(name: "Dish Soap")
    ]
}
