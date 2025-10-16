import XCTest
@testable import FamilyAppCore

final class AuthenticationControllerTests: XCTestCase {
    func testSignUpTransitionsSessionToAwaitingFamily() async throws {
        let authService = MockAuthService()
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = AuthenticationController(authService: authService, familyRepository: repository, sessionStore: sessionStore)

        let request = SignUpRequest(
            email: "test@example.com",
            password: "password",
            confirmPassword: "password",
            displayName: "Test User"
        )

        try await controller.signUp(request: request)
        let state = await sessionStore.currentState()

        guard case let .awaitingFamily(user) = state else {
            XCTFail("Expected awaitingFamily state")
            return
        }
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertNil(user.familyID)
    }

    func testLoginWithExistingFamilyRoutesToActiveState() async throws {
        let authService = MockAuthService()
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = AuthenticationController(authService: authService, familyRepository: repository, sessionStore: sessionStore)

        let ownerID = "owner"
        let seededFamily = try await repository.createFamily(name: "Smith Family", username: "smiths", lastName: "Smith", ownerID: ownerID)

        authService.loginHandler = { email, _ in
            User(id: "member", email: email, displayName: "Member", familyID: seededFamily.id)
        }

        try await controller.login(request: LoginRequest(email: "member@smith.com", password: "secret"))
        let state = await sessionStore.currentState()
        guard case let .active(user, activeFamily) = state else {
            XCTFail("Expected active state")
            return
        }
        XCTAssertEqual(user.familyID, seededFamily.id)
        XCTAssertEqual(activeFamily.id, seededFamily.id)
        XCTAssertTrue(activeFamily.members.contains("member"))
    }

    func testSignUpValidationFailsForInvalidEmail() async {
        let authService = MockAuthService()
        let repository = MockFamilyRepository()
        let sessionStore = SessionStore()
        let controller = AuthenticationController(authService: authService, familyRepository: repository, sessionStore: sessionStore)

        let request = SignUpRequest(
            email: "invalid-email",
            password: "password",
            confirmPassword: "password",
            displayName: nil
        )

        await XCTAssertThrowsErrorAsync(try await controller.signUp(request: request)) { error in
            XCTAssertEqual(error as? AuthenticationFlowError, .invalidEmail)
        }
    }
}

