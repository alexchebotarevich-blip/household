import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

public final class FirestoreFamilyRepository: FamilyRepository {
    private let families = Firestore.firestore().collection("families")
    private let users = Firestore.firestore().collection("users")
    private let invitations = Firestore.firestore().collection("familyInvitations")

    public init() {}

    public func createFamily(name: String, username: String, lastName: String, ownerID: String) async throws -> Family {
        let username = username.lowercased()
        let existingSnapshot = try await families.whereField("username", isEqualTo: username).getDocuments()
        guard existingSnapshot.documents.isEmpty else {
            throw FamilyRepositoryError.familyAlreadyExists
        }

        let familyID = UUID().uuidString
        let invitationCode = generateInvitationCode()

        let payload: [String: Any] = [
            "name": name,
            "username": username,
            "lastName": lastName,
            "invitationCode": invitationCode,
            "members": [ownerID]
        ]

        try await families.document(familyID).setData(payload)
        try await users.document(ownerID).setData(["familyID": familyID], merge: true)

        return Family(
            id: familyID,
            name: name,
            username: username,
            lastName: lastName,
            invitationCode: invitationCode,
            members: Set([ownerID])
        )
    }

    public func joinFamily(byUsername username: String, userID: String) async throws -> Family {
        try await performMembershipMutation(userID: userID) { family in
            family.username == username.lowercased()
        }
    }

    public func joinFamily(byLastName lastName: String, userID: String) async throws -> Family {
        try await performMembershipMutation(userID: userID) { family in
            family.lastName.caseInsensitiveCompare(lastName) == .orderedSame
        }
    }

    public func joinFamily(usingInvitation code: String, userID: String) async throws -> Family {
        let invitationSnapshot = try await invitations.whereField("code", isEqualTo: code.uppercased()).getDocuments()
        guard let document = invitationSnapshot.documents.first else {
            throw FamilyRepositoryError.invitationNotFound
        }
        let familyID = document.get("familyID") as? String ?? ""
        return try await performJoin(familyID: familyID, userID: userID)
    }

    public func fetchFamily(id: String) async throws -> Family? {
        let snapshot = try await families.document(id).getDocument()
        guard let data = snapshot.data() else { return nil }
        return try family(from: data, id: snapshot.documentID)
    }

    public func generateInvitation(for familyID: String, invitedBy userID: String) async throws -> FamilyInvitation {
        let code = generateInvitationCode()
        let payload: [String: Any] = [
            "code": code,
            "familyID": familyID,
            "invitedBy": userID,
            "createdAt": Timestamp(date: Date())
        ]
        try await invitations.document(code).setData(payload)
        return FamilyInvitation(code: code, familyID: familyID, invitedByUserID: userID)
    }

    private func performMembershipMutation(
        userID: String,
        filter: @escaping (Family) -> Bool
    ) async throws -> Family {
        let snapshot = try await families.getDocuments()
        let families = try snapshot.documents.compactMap { document in
            try family(from: document.data(), id: document.documentID)
        }
        guard let targetFamily = families.first(where: filter) else {
            throw FamilyRepositoryError.familyNotFound
        }
        return try await performJoin(familyID: targetFamily.id, userID: userID)
    }

    private func performJoin(familyID: String, userID: String) async throws -> Family {
        let familyRef = families.document(familyID)
        return try await Firestore.firestore().runTransaction { transaction, _ in
            let snapshot = try transaction.getDocument(familyRef)
            guard var data = snapshot.data() else {
                throw FamilyRepositoryError.familyNotFound
            }
            var members = Set(data["members"] as? [String] ?? [])
            guard members.insert(userID).inserted else {
                throw FamilyRepositoryError.userAlreadyMember
            }
            data["members"] = Array(members)
            transaction.setData(data, forDocument: familyRef)
            transaction.setData(["familyID": familyID], forDocument: self.users.document(userID), merge: true)
            return try self.family(from: data, id: snapshot.documentID)
        }
    }

    private func family(from data: [String: Any], id: String) throws -> Family {
        guard
            let name = data["name"] as? String,
            let username = data["username"] as? String,
            let lastName = data["lastName"] as? String,
            let invitationCode = data["invitationCode"] as? String
        else {
            throw FamilyRepositoryError.familyNotFound
        }
        let members = Set(data["members"] as? [String] ?? [])
        return Family(id: id, name: name, username: username, lastName: lastName, invitationCode: invitationCode, members: members)
    }

    private func generateInvitationCode() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).uppercased()
    }
}
#endif
