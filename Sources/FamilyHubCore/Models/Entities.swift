import Foundation

public struct AppUser: FirestoreEntity {
    public struct DeviceToken: Codable, Equatable, Sendable {
        public var token: String
        public var lastUpdated: Date

        public init(token: String, lastUpdated: Date) {
            self.token = token
            self.lastUpdated = lastUpdated
        }
    }

    public static let collection: FirestoreCollection = .users

    public let id: String
    public var email: String
    public var displayName: String
    public var photoURL: URL?
    public var familyID: String?
    public var roleIDs: [String]
    public var deviceTokens: [DeviceToken]
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String,
        email: String,
        displayName: String,
        photoURL: URL?,
        familyID: String?,
        roleIDs: [String],
        deviceTokens: [DeviceToken],
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date?
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.familyID = familyID
        self.roleIDs = roleIDs
        self.deviceTokens = deviceTokens
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FamilyRole: FirestoreEntity {
    public enum Permission: String, Codable, CaseIterable, Sendable {
        case manageFamily
        case manageMembers
        case manageTasks
        case manageShopping
        case viewAnalytics
    }

    public struct Metadata: Codable, Equatable, Sendable {
        public var assignmentLabel: String
        public var analyticsTag: String
        public var iconName: String?

        public init(assignmentLabel: String, analyticsTag: String, iconName: String? = nil) {
            self.assignmentLabel = assignmentLabel
            self.analyticsTag = analyticsTag
            self.iconName = iconName
        }
    }

    public static let collection: FirestoreCollection = .familyRoles

    public let id: String
    public var familyID: String
    public var title: String
    public var description: String?
    public var permissions: [Permission]
    public var displayOrder: Int
    public var isDefault: Bool
    public var metadata: Metadata
    public var createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String,
        familyID: String,
        title: String,
        description: String?,
        permissions: [Permission],
        displayOrder: Int,
        isDefault: Bool,
        metadata: Metadata,
        createdAt: Date,
        updatedAt: Date?
    ) {
        self.id = id
        self.familyID = familyID
        self.title = title
        self.description = description
        self.permissions = permissions
        self.displayOrder = displayOrder
        self.isDefault = isDefault
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension FamilyRole {
    struct Template: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let description: String
        public let permissions: [Permission]
        public let metadata: Metadata

        public init(
            id: String = UUID().uuidString,
            title: String,
            description: String,
            permissions: [Permission],
            metadata: Metadata
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.permissions = permissions
            self.metadata = metadata
        }

        public func makeRole(
            familyID: String,
            displayOrder: Int,
            isDefault: Bool = false,
            createdAt: Date = Date()
        ) -> FamilyRole {
            FamilyRole(
                id: UUID().uuidString,
                familyID: familyID,
                title: title,
                description: description,
                permissions: permissions,
                displayOrder: displayOrder,
                isDefault: isDefault,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: nil
            )
        }
    }

    static let defaultTemplates: [Template] = [
        Template(
            title: "Partner",
            description: "Shares household planning and decisions",
            permissions: Permission.allCases,
            metadata: Metadata(
                assignmentLabel: "Assign to partner",
                analyticsTag: "partner",
                iconName: "heart.fill"
            )
        ),
        Template(
            title: "Child",
            description: "Focuses on assigned chores and personal tasks",
            permissions: [.manageTasks, .manageShopping],
            metadata: Metadata(
                assignmentLabel: "Assign to child",
                analyticsTag: "child",
                iconName: "figure.and.child.holdinghands"
            )
        ),
        Template(
            title: "Grandparent",
            description: "Helps with oversight and celebrations",
            permissions: [.manageFamily, .manageShopping],
            metadata: Metadata(
                assignmentLabel: "Assign to grandparent",
                analyticsTag: "grandparent",
                iconName: "person.2.square.stack"
            )
        ),
        Template(
            title: "Caregiver",
            description: "Supports routines and schedules",
            permissions: [.manageTasks, .manageShopping],
            metadata: Metadata(
                assignmentLabel: "Assign to caregiver",
                analyticsTag: "caregiver",
                iconName: "stethoscope"
            )
        ),
        Template(
            title: "Pet",
            description: "Track pet related responsibilities",
            permissions: [.manageTasks],
            metadata: Metadata(
                assignmentLabel: "Assign to pet",
                analyticsTag: "pet",
                iconName: "pawprint.fill"
            )
        )
    ]
}

public struct Family: FirestoreEntity {
    public struct Member: Codable, Equatable, Sendable {
        public var userID: String
        public var roleIDs: [String]
        public var joinedAt: Date
        public var invitedBy: String?

        public init(userID: String, roleIDs: [String], joinedAt: Date, invitedBy: String?) {
            self.userID = userID
            self.roleIDs = roleIDs
            self.joinedAt = joinedAt
            self.invitedBy = invitedBy
        }
    }

    public static let collection: FirestoreCollection = .families

    public let id: String
    public var name: String
    public var ownerID: String
    public var members: [Member]
    public var photoURL: URL?
    public var createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        ownerID: String,
        members: [Member],
        photoURL: URL?,
        createdAt: Date,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.members = members
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TaskItem: FirestoreEntity {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case pending
        case inProgress
        case completed
        case archived
    }

    public enum Priority: String, Codable, CaseIterable, Sendable {
        case low
        case medium
        case high
        case urgent
    }

    public struct RepeatRule: Codable, Equatable, Sendable {
        public enum Frequency: String, Codable, CaseIterable, Sendable {
            case daily
            case weekly
            case monthly
            case yearly
        }

        public var frequency: Frequency
        public var interval: Int
        public var daysOfWeek: [Int]?

        public init(frequency: Frequency, interval: Int, daysOfWeek: [Int]?) {
            self.frequency = frequency
            self.interval = interval
            self.daysOfWeek = daysOfWeek
        }
    }

    public struct ChecklistItem: Codable, Equatable, Sendable {
        public var title: String
        public var isDone: Bool
        public var assignedTo: String?

        public init(title: String, isDone: Bool, assignedTo: String?) {
            self.title = title
            self.isDone = isDone
            self.assignedTo = assignedTo
        }
    }

    public static let collection: FirestoreCollection = .tasks

    public let id: String
    public var familyID: String
    public var name: String
    public var details: String?
    public var dueDate: Date?
    public var status: Status
    public var priority: Priority
    public var assigneeIDs: [String]
    public var repeatRule: RepeatRule?
    public var checklist: [ChecklistItem]
    public var createdBy: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var completedAt: Date?

    public init(
        id: String,
        familyID: String,
        name: String,
        details: String?,
        dueDate: Date?,
        status: Status,
        priority: Priority,
        assigneeIDs: [String],
        repeatRule: RepeatRule?,
        checklist: [ChecklistItem],
        createdBy: String,
        createdAt: Date,
        updatedAt: Date?,
        completedAt: Date?
    ) {
        self.id = id
        self.familyID = familyID
        self.name = name
        self.details = details
        self.dueDate = dueDate
        self.status = status
        self.priority = priority
        self.assigneeIDs = assigneeIDs
        self.repeatRule = repeatRule
        self.checklist = checklist
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct ShoppingItem: FirestoreEntity {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case pending
        case purchased
        case cancelled
    }

    public static let collection: FirestoreCollection = .shoppingItems

    public let id: String
    public var familyID: String
    public var name: String
    public var quantity: Double
    public var unit: String?
    public var notes: String?
    public var status: Status
    public var createdBy: String
    public var assigneeID: String?
    public var purchasedBy: String?
    public var createdAt: Date
    public var updatedAt: Date?
    public var purchasedAt: Date?

    public init(
        id: String,
        familyID: String,
        name: String,
        quantity: Double,
        unit: String?,
        notes: String?,
        status: Status,
        createdBy: String,
        assigneeID: String?,
        purchasedBy: String?,
        createdAt: Date,
        updatedAt: Date?,
        purchasedAt: Date?
    ) {
        self.id = id
        self.familyID = familyID
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
        self.status = status
        self.createdBy = createdBy
        self.assigneeID = assigneeID
        self.purchasedBy = purchasedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.purchasedAt = purchasedAt
    }
}

public struct ActivityLog: FirestoreEntity {
    public enum Action: String, Codable, CaseIterable, Sendable {
        case userInvited
        case userJoined
        case userRemoved
        case roleUpdated
        case taskCreated
        case taskUpdated
        case taskCompleted
        case taskDeleted
        case shoppingItemAdded
        case shoppingItemPurchased
        case shoppingItemDeleted
        case familyUpdated
    }

    public static let collection: FirestoreCollection = .activityLogs

    public let id: String
    public var familyID: String
    public var actorID: String
    public var action: Action
    public var targetID: String?
    public var message: String
    public var metadata: [String: String]
    public var createdAt: Date

    public init(
        id: String,
        familyID: String,
        actorID: String,
        action: Action,
        targetID: String?,
        message: String,
        metadata: [String: String],
        createdAt: Date
    ) {
        self.id = id
        self.familyID = familyID
        self.actorID = actorID
        self.action = action
        self.targetID = targetID
        self.message = message
        self.metadata = metadata
        self.createdAt = createdAt
    }
}
