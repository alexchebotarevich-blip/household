import Foundation

public enum AuthenticationFlowError: Error, Equatable, LocalizedError, Sendable {
    case invalidEmail
    case weakPassword
    case passwordsDoNotMatch
    case emptyField(_ field: String)
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        case let .emptyField(field):
            return "The \(field) field cannot be empty."
        case let .underlying(error):
            return (error as NSError).localizedDescription
        }
    }
}

public protocol AuthService: Sendable {
    var currentUser: User? { get }

    func signUp(email: String, password: String, displayName: String?) async throws -> User
    func login(email: String, password: String) async throws -> User
    func sendPasswordReset(email: String) async throws
    func signInWithApple() async throws -> User
    func signOut() throws
}
