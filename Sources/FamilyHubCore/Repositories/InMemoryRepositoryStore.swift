import Foundation

final class InMemoryRepositoryStore {
    private var users: [String: (user: AppUser, password: String)] = [:]
    private var families: [String: Family] = [:]
    private var roles: [String: Role] = [:]
    private var tasks: [String: [String: TaskItem]] = [:] // familyID -> taskID -> TaskItem
    private var shoppingItems: [String: [String: ShoppingItem]] = [:] // familyID -> itemID -> ShoppingItem
    private var activityLogs: [String: [ActivityLog]] = [:] // familyID -> logs
    private let accessQueue = DispatchQueue(label: "InMemoryRepositoryStore.access", attributes: .concurrent)

    func saveUser(_ user: AppUser, password: String) {
        accessQueue.sync(flags: .barrier) {
            self.users[user.id] = (user, password)
        }
    }

    func updateUser(_ user: AppUser) {
        accessQueue.sync(flags: .barrier) {
            guard let password = self.users[user.id]?.password else { return }
            self.users[user.id] = (user, password)
        }
    }

    func user(withEmail email: String) -> (user: AppUser, password: String)? {
        accessQueue.sync {
            users.values.first { $0.user.email.caseInsensitiveCompare(email) == .orderedSame }
        }
    }

    func user(withID id: String) -> AppUser? {
        accessQueue.sync { users[id]?.user }
    }

    func saveRole(_ role: Role) {
        accessQueue.sync(flags: .barrier) {
            self.roles[role.id] = role
        }
    }

    func role(withID id: String) -> Role? {
        accessQueue.sync { roles[id] }
    }

    func allRoles() -> [Role] {
        accessQueue.sync { Array(roles.values) }
    }

    func saveFamily(_ family: Family) {
        accessQueue.sync(flags: .barrier) {
            self.families[family.id] = family
        }
    }

    func family(withID id: String) -> Family? {
        accessQueue.sync { families[id] }
    }

    func families(forUserID userID: String) -> [Family] {
        accessQueue.sync {
            families.values.filter { family in
                family.members.contains { $0.userID == userID }
            }
        }
    }

    func saveTask(_ task: TaskItem) {
        accessQueue.sync(flags: .barrier) {
            var familyTasks = self.tasks[task.familyID, default: [:]]
            familyTasks[task.id] = task
            self.tasks[task.familyID] = familyTasks
        }
    }

    func task(familyID: String, taskID: String) -> TaskItem? {
        accessQueue.sync {
            tasks[familyID]?[taskID]
        }
    }

    func deleteTask(familyID: String, taskID: String) -> TaskItem? {
        accessQueue.sync(flags: .barrier) {
            guard var familyTasks = self.tasks[familyID] else { return nil }
            let removed = familyTasks.removeValue(forKey: taskID)
            self.tasks[familyID] = familyTasks
            return removed
        }
    }

    func tasks(for familyID: String) -> [TaskItem] {
        accessQueue.sync {
            guard let values = tasks[familyID]?.values else { return [] }
            return Array(values)
        }
    }

    func saveShoppingItem(_ item: ShoppingItem) {
        accessQueue.sync(flags: .barrier) {
            var familyItems = self.shoppingItems[item.familyID, default: [:]]
            familyItems[item.id] = item
            self.shoppingItems[item.familyID] = familyItems
        }
    }

    func deleteShoppingItem(familyID: String, itemID: String) -> ShoppingItem? {
        accessQueue.sync(flags: .barrier) {
            guard var familyItems = self.shoppingItems[familyID] else { return nil }
            let removed = familyItems.removeValue(forKey: itemID)
            self.shoppingItems[familyID] = familyItems
            return removed
        }
    }

    func shoppingItems(for familyID: String) -> [ShoppingItem] {
        accessQueue.sync {
            guard let values = shoppingItems[familyID]?.values else { return [] }
            return Array(values)
        }
    }

    func appendActivityLog(_ log: ActivityLog) {
        accessQueue.sync(flags: .barrier) {
            var logs = self.activityLogs[log.familyID, default: []]
            logs.append(log)
            self.activityLogs[log.familyID] = logs
        }
    }

    func activityLogs(for familyID: String) -> [ActivityLog] {
        accessQueue.sync { activityLogs[familyID] ?? [] }
    }
}
