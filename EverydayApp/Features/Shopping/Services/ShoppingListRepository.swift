import Foundation
import Combine

protocol ShoppingListRepository {
    var updates: AnyPublisher<[ShoppingItem], Never> { get }
    var activityUpdates: AnyPublisher<[ShoppingActivityLogEntry], Never> { get }

    func add(_ item: ShoppingItem)
    func update(_ item: ShoppingItem)
    @discardableResult
    func delete(id: UUID, actor: ShoppingUser) -> ShoppingItem?
    func restore(_ item: ShoppingItem)
    func markPurchased(id: UUID, by user: ShoppingUser) -> ShoppingItem?
    func markPending(id: UUID) -> ShoppingItem?
    func item(with id: UUID) -> ShoppingItem?
}

final class OfflineFirstShoppingRepository: ShoppingListRepository {
    static let shared = OfflineFirstShoppingRepository()

    private let storageQueue = DispatchQueue(label: "OfflineFirstShoppingRepository.storage", attributes: .concurrent)
    private let cache: ShoppingListCache
    private let itemsSubject: CurrentValueSubject<[ShoppingItem], Never>
    private let activitySubject: CurrentValueSubject<[ShoppingActivityLogEntry], Never>
    private var itemsByID: [UUID: ShoppingItem]

    init(cache: ShoppingListCache = ShoppingListCache()) {
        self.cache = cache
        let cachedItems = cache.loadItems()
        let initialItems = cachedItems.isEmpty ? ShoppingItem.samples : cachedItems
        let cachedActivities = cache.loadActivityEntries()
        let initialActivities: [ShoppingActivityLogEntry]
        if cachedActivities.isEmpty {
            initialActivities = OfflineFirstShoppingRepository.bootstrapActivities(from: initialItems)
        } else {
            initialActivities = cachedActivities.sorted { $0.timestamp > $1.timestamp }
        }
        self.itemsByID = Dictionary(uniqueKeysWithValues: initialItems.map { ($0.id, $0) })
        self.itemsSubject = CurrentValueSubject(OfflineFirstShoppingRepository.sortedItems(from: initialItems))
        self.activitySubject = CurrentValueSubject(initialActivities)
    }

    var updates: AnyPublisher<[ShoppingItem], Never> {
        itemsSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var activityUpdates: AnyPublisher<[ShoppingActivityLogEntry], Never> {
        activitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func add(_ item: ShoppingItem) {
        performWrite { items in
            items[item.id] = item
        }
    }

    func update(_ item: ShoppingItem) {
        performWrite { items in
            guard items[item.id] != nil else { return }
            items[item.id] = item
        }
    }

    @discardableResult
    func delete(id: UUID, actor: ShoppingUser) -> ShoppingItem? {
        var removedItem: ShoppingItem?
        performWrite { items in
            removedItem = items.removeValue(forKey: id)
        }
        if let removedItem {
            appendActivity(
                ShoppingActivityLogEntry(
                    itemID: removedItem.id,
                    itemName: removedItem.name,
                    quantity: removedItem.quantity,
                    category: removedItem.category,
                    actorName: actor.displayName,
                    action: .removed,
                    timestamp: Date()
                )
            )
        }
        return removedItem
    }

    func restore(_ item: ShoppingItem) {
        performWrite { items in
            items[item.id] = item
        }
    }

    func markPurchased(id: UUID, by user: ShoppingUser) -> ShoppingItem? {
        var updatedItem: ShoppingItem?
        performWrite { items in
            guard var current = items[id] else { return }
            current.status = .purchased
            current.purchasedBy = user.displayName
            let timestamp = Date()
            current.purchasedAt = timestamp
            current.updatedAt = timestamp
            items[id] = current
            updatedItem = current
        }

        if let updatedItem {
            appendActivity(
                ShoppingActivityLogEntry(
                    itemID: updatedItem.id,
                    itemName: updatedItem.name,
                    quantity: updatedItem.quantity,
                    category: updatedItem.category,
                    actorName: user.displayName,
                    action: .purchased,
                    timestamp: updatedItem.purchasedAt ?? Date()
                )
            )
        }

        return updatedItem
    }

    func markPending(id: UUID) -> ShoppingItem? {
        var updatedItem: ShoppingItem?
        performWrite { items in
            guard var current = items[id] else { return }
            current.status = .pending
            current.purchasedBy = nil
            current.purchasedAt = nil
            current.updatedAt = Date()
            items[id] = current
            updatedItem = current
        }
        return updatedItem
    }

    func item(with id: UUID) -> ShoppingItem? {
        storageQueue.sync {
            itemsByID[id]
        }
    }

    private func performWrite(_ mutation: @escaping (inout [UUID: ShoppingItem]) -> Void) {
        storageQueue.async(flags: .barrier) {
            var items = self.itemsByID
            mutation(&items)
            self.itemsByID = items
            let sorted = OfflineFirstShoppingRepository.sortedItems(from: Array(items.values))
            self.itemsSubject.send(sorted)
            self.cache.saveItems(sorted)
        }
    }

    private func appendActivity(_ entry: ShoppingActivityLogEntry) {
        storageQueue.async(flags: .barrier) {
            var existing = self.activitySubject.value
            existing.insert(entry, at: 0)
            self.activitySubject.send(existing)
            self.cache.saveActivityEntries(existing)
        }
    }

    private static func sortedItems(from items: [ShoppingItem]) -> [ShoppingItem] {
        items.sorted { lhs, rhs in
            switch (lhs.status, rhs.status) {
            case (.pending, .purchased):
                return true
            case (.purchased, .pending):
                return false
            default:
                let lhsDate = lhs.updatedAt ?? lhs.createdAt
                let rhsDate = rhs.updatedAt ?? rhs.createdAt
                return lhsDate > rhsDate
            }
        }
    }

    private static func bootstrapActivities(from items: [ShoppingItem]) -> [ShoppingActivityLogEntry] {
        items
            .compactMap { item in
                guard item.status == .purchased, let purchasedAt = item.purchasedAt else { return nil }
                return ShoppingActivityLogEntry(
                    itemID: item.id,
                    itemName: item.name,
                    quantity: item.quantity,
                    category: item.category,
                    actorName: item.purchasedBy ?? "Household",
                    action: .purchased,
                    timestamp: purchasedAt
                )
            }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

struct ShoppingListCache {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let itemsURL: URL
    private let activityURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let baseDirectory = directory ?? ShoppingListCache.defaultDirectory(with: fileManager)
        self.directoryURL = baseDirectory
        self.itemsURL = baseDirectory.appendingPathComponent("items.json")
        self.activityURL = baseDirectory.appendingPathComponent("activity.json")
        self.encoder = ShoppingListCache.makeEncoder()
        self.decoder = ShoppingListCache.makeDecoder()
        createDirectoryIfNeeded()
    }

    func loadItems() -> [ShoppingItem] {
        guard let data = try? Data(contentsOf: itemsURL) else { return [] }
        return (try? decoder.decode([ShoppingItem].self, from: data)) ?? []
    }

    func saveItems(_ items: [ShoppingItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: itemsURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist shopping items: \(error)")
            #endif
        }
    }

    func loadActivityEntries() -> [ShoppingActivityLogEntry] {
        guard let data = try? Data(contentsOf: activityURL) else { return [] }
        return (try? decoder.decode([ShoppingActivityLogEntry].self, from: data)) ?? []
    }

    func saveActivityEntries(_ entries: [ShoppingActivityLogEntry]) {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: activityURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist shopping activity log: \(error)")
            #endif
        }
    }

    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("⚠️ Failed to create shopping cache directory: \(error)")
            #endif
        }
    }

    private static func defaultDirectory(with fileManager: FileManager) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("shopping-cache", isDirectory: true)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
