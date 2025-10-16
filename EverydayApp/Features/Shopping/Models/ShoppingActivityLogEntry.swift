import Foundation

struct ShoppingUser: Equatable {
    let id: String
    let displayName: String

    static let current = ShoppingUser(id: "local-user", displayName: "You")
}

struct ShoppingActivityLogEntry: Identifiable, Codable, Equatable {
    enum Action: String, Codable {
        case purchased
        case removed
    }

    let id: UUID
    let itemID: UUID
    let itemName: String
    let quantity: Double
    let category: String
    let actorName: String
    let action: Action
    let timestamp: Date

    init(
        id: UUID = UUID(),
        itemID: UUID,
        itemName: String,
        quantity: Double,
        category: String,
        actorName: String,
        action: Action,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.quantity = quantity
        self.category = category
        self.actorName = actorName
        self.action = action
        self.timestamp = timestamp
    }
}

extension ShoppingActivityLogEntry {
    var description: String {
        switch action {
        case .purchased:
            return "\(actorName) purchased \(itemName)"
        case .removed:
            return "\(actorName) removed \(itemName)"
        }
    }

    var detailSummary: String {
        let formatter = ShoppingActivityLogEntry.relativeFormatter
        let relative = formatter.localizedString(for: timestamp, relativeTo: Date())
        return "Qty: \(quantityText) • \(category) • \(relative)"
    }

    private var quantityText: String {
        if quantity.isApproximatelyInteger {
            return String(Int(quantity.rounded()))
        }
        return String(format: "%.1f", quantity)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

private extension Double {
    var isApproximatelyInteger: Bool {
        abs(self.rounded() - self) < 0.001
    }
}
