import Foundation
import Combine

final class ShoppingViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []

    init(items: [ShoppingItem] = ShoppingItem.samples) {
        self.items = items
    }

    func addItem(name: String, quantity: Int, notes: String?) {
        let item = ShoppingItem(name: name, quantity: quantity, notes: notes)
        items.append(item)
    }
}
