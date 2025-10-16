import Foundation

final class InMemoryRepositoryStore {
    private var users: [String: (user: AppUser, password: String)] = [:]
    private var families: [String: Family] = [:]
    private var familyRoles: [String: [String: FamilyRole]] = [:] // familyID -> roleID -> FamilyRole
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

    func saveRole(_ role: FamilyRole) {
        accessQueue.sync(flags: .barrier) {
            var roles = self.familyRoles[role.familyID, default: [:]]
            roles[role.id] = role
            self.familyRoles[role.familyID] = roles
        }
    }

    func role(familyID: String, roleID: String) -> FamilyRole? {
        accessQueue.sync { familyRoles[familyID]?[roleID] }
    }

    func deleteRole(familyID: String, roleID: String) -> FamilyRole? {
        accessQueue.sync(flags: .barrier) {
            guard var roles = self.familyRoles[familyID] else { return nil }
            let removed = roles.removeValue(forKey: roleID)
            self.familyRoles[familyID] = roles
            return removed
        }
    }

    func roles(familyID: String) -> [FamilyRole] {
        accessQueue.sync {
            guard let values = familyRoles[familyID]?.values else { return [] }
            return values.sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.displayOrder < rhs.displayOrder
            }
        }
    }

    func replaceRoles(_ roles: [FamilyRole], for familyID: String) {
        accessQueue.sync(flags: .barrier) {
            var dictionary: [String: FamilyRole] = [:]
            for role in roles {
                dictionary[role.id] = role
            }
            self.familyRoles[familyID] = dictionary
        }
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
