import XCTest
@testable import FamilyAppCore

final class FamilyOnboardingControllerTests: XCTestCase {
    func testCreateFamilyMovesAwaitingUserToActiveState() async throws {
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = FamilyOnboardingController(repository: repository, sessionStore: sessionStore)
        let user = User(id: "user1", email: "user@example.com")
        await sessionStore.update(.awaitingFamily(user: user))

        let request = CreateFamilyRequest(name: "The Taylors", username: "taylorcrew", lastName: "Taylor")
        try await controller.createFamily(request: request)

        let state = await sessionStore.currentState()
        guard case let .active(activeUser, family) = state else {
            XCTFail("Expected active state after creating family")
            return
        }
        XCTAssertEqual(activeUser.familyID, family.id)
        XCTAssertEqual(family.username, "taylorcrew")
        XCTAssertTrue(family.members.contains(user.id))
    }

    func testJoinFamilyByUsernameActivatesSession() async throws {
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = FamilyOnboardingController(repository: repository, sessionStore: sessionStore)
        let owner = User(id: "owner", email: "owner@example.com")
        _ = try await repository.createFamily(name: "The Lees", username: "leecrew", lastName: "Lee", ownerID: owner.id)

        let awaitingUser = User(id: "joiner", email: "joiner@example.com")
        await sessionStore.update(.awaitingFamily(user: awaitingUser))

        try await controller.joinFamily(byUsername: "leecrew")
        let state = await sessionStore.currentState()
        guard case let .active(activeUser, family) = state else {
            XCTFail("Expected active state after join")
            return
        }
        XCTAssertEqual(activeUser.id, awaitingUser.id)
        XCTAssertEqual(family.id, activeUser.familyID)
        XCTAssertTrue(family.members.contains(awaitingUser.id))
    }

    func testInviteMembersReturnsShareableCode() async throws {
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let onboarding = FamilyOnboardingController(repository: repository, sessionStore: sessionStore)
        let owner = User(id: "owner", email: "owner@example.com")
        await sessionStore.update(.awaitingFamily(user: owner))
        try await onboarding.createFamily(request: CreateFamilyRequest(name: "The Watts", username: "wattsfam", lastName: "Watts"))

        let invitation = try await onboarding.inviteMembers()
        XCTAssertEqual(invitation.invitedByUserID, owner.id)
        XCTAssertFalse(invitation.code.isEmpty)
    }

    func testCreatingFamilyWithoutAwaitingStateThrows() async {
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = FamilyOnboardingController(repository: repository, sessionStore: sessionStore)

        await XCTAssertThrowsErrorAsync(try await controller.createFamily(request: CreateFamilyRequest(name: "The Parks", username: "parks", lastName: "Park"))) { error in
            XCTAssertEqual(error as? FamilyOnboardingError, .invalidState)
        }
    }
}
