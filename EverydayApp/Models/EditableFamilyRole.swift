import FamilyHubCore
import Foundation

struct EditableFamilyRole: Identifiable, Equatable {
    let id: String
    var title: String
    var description: String
    var permissions: [FamilyRole.Permission]
    var assignmentLabel: String
    var analyticsTag: String
    var iconName: String?
    var displayOrder: Int
    var isDefault: Bool

    init(role: FamilyRole) {
        id = role.id
        title = role.title
        description = role.description ?? ""
        permissions = role.permissions
        assignmentLabel = role.metadata.assignmentLabel
        analyticsTag = role.metadata.analyticsTag
        iconName = role.metadata.iconName
        displayOrder = role.displayOrder
        isDefault = role.isDefault
    }

    init(
        id: String,
        title: String,
        description: String = "",
        permissions: [FamilyRole.Permission],
        assignmentLabel: String,
        analyticsTag: String,
        iconName: String? = nil,
        displayOrder: Int,
        isDefault: Bool
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.permissions = permissions
        self.assignmentLabel = assignmentLabel
        self.analyticsTag = analyticsTag
        self.iconName = iconName
        self.displayOrder = displayOrder
        self.isDefault = isDefault
    }

    func applying(to role: FamilyRole) -> FamilyRole {
        var updated = role
        updated.title = title
        updated.description = description.isEmpty ? nil : description
        updated.permissions = permissions
        updated.displayOrder = displayOrder
        updated.isDefault = isDefault
        updated.metadata = FamilyRole.Metadata(
            assignmentLabel: assignmentLabel,
            analyticsTag: analyticsTag,
            iconName: iconName
        )
        return updated
    }
}
