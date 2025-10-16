import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth

public final class FirebaseAuthService: AuthService {
    public init() {}

    public var currentUser: User? {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            return nil
        }
        return User(
            id: user.uid,
            email: email,
            displayName: user.displayName,
            familyID: nil
        )
    }

    public func signUp(email: String, password: String, displayName: String?) async throws -> User {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = authResult.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        return User(
            id: authResult.user.uid,
            email: email,
            displayName: displayName,
            familyID: nil
        )
    }

    public func login(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return User(
            id: result.user.uid,
            email: email,
            displayName: result.user.displayName,
            familyID: nil
        )
    }

    public func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    public func signInWithApple() async throws -> User {
        throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Sign in with Apple is not configured."
        ])
    }

    public func signOut() throws {
        try Auth.auth().signOut()
    }
}
#endif
