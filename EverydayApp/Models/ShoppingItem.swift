import Foundation

struct ShoppingItem: Identifiable, Codable, Equatable {
    enum Status: String, Codable, CaseIterable {
        case pending
        case purchased
        case cancelled

        var displayName: String {
            switch self {
            case .pending:
                return "Pending"
            case .purchased:
                return "Purchased"
            case .cancelled:
                return "Cancelled"
            }
        }
    }

    let id: UUID
    var name: String
    var quantity: Double
    var category: String
    var notes: String?
    var assignee: String?
    var status: Status
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date?
    var purchasedBy: String?
    var purchasedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        category: String = "General",
        notes: String? = nil,
        assignee: String? = nil,
        status: Status = .pending,
        createdBy: String = "You",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        purchasedBy: String? = nil,
        purchasedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.notes = notes
        self.assignee = assignee
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.purchasedBy = purchasedBy
        self.purchasedAt = purchasedAt
    }
}

extension ShoppingItem {
    var isPurchased: Bool {
        status == .purchased
    }

    var quantityDescription: String {
        if quantity.isApproximatelyInteger {
            return "x\(Int(quantity.rounded()))"
        }
        return String(format: "%.1fx", quantity)
    }

    var detailSummary: String {
        var components: [String] = ["Qty: \(quantityDescription)"]
        if !category.isEmpty {
            components.append(category)
        }
        if let assignee, !assignee.isEmpty {
            components.append("For: \(assignee)")
        }
        return components.joined(separator: " • ")
    }

    var purchasedSummary: String? {
        guard let purchaser = purchasedBy, let timestamp = purchasedAt else { return nil }
        let formatter = ShoppingItem.relativeFormatter
        return "Purchased by \(purchaser) · \(formatter.localizedString(for: timestamp, relativeTo: Date()))"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

private extension Double {
    var isApproximatelyInteger: Bool {
        abs(self.rounded() - self) < 0.001
    }
}

extension ShoppingItem {
    static let samples: [ShoppingItem] = [
        ShoppingItem(name: "Oat Milk",
                     quantity: 2,
                     category: "Dairy",
                     notes: "Unsweetened preferred",
                     assignee: "Alex"),
        ShoppingItem(name: "Blueberries",
                     quantity: 1,
                     category: "Produce",
                     notes: "Organic if available",
                     assignee: nil,
                     status: .pending),
        ShoppingItem(name: "Dish Soap",
                     quantity: 1,
                     category: "Household",
                     status: .purchased,
                     purchasedBy: "Jamie",
                     purchasedAt: Date().addingTimeInterval(-3_600))
    ]
}
