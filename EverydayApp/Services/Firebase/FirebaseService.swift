import Foundation
import Combine
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import CombineExt

enum FirebaseConfigurationError: LocalizedError {
    case missingConfigurationFile

    var errorDescription: String? {
        switch self {
        case .missingConfigurationFile:
            return "Firebase GoogleService-Info.plist is missing from the bundle."
        }
    }
}

enum FirebaseMessagingError: LocalizedError {
    case tokenUnavailable

    var errorDescription: String? {
        "Firebase messaging token is unavailable."
    }
}

enum FirebaseConfigurator {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }

        let bundle = Bundle.main
        let hasGoogleServiceFile = bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil

        guard hasGoogleServiceFile else {
            #if DEBUG
            print("⚠️ Firebase configuration skipped: GoogleService-Info.plist not found.")
            #endif
            return
        }

        FirebaseApp.configure()
    }
}

protocol FirebaseAuthServicing {
    var authenticationState: AnyPublisher<Bool, Never> { get }
    func signInAnonymously() -> AnyPublisher<Bool, Error>
}

final class FirebaseAuthService: FirebaseAuthServicing {
    private let stateSubject: CurrentValueSubject<Bool, Never>

    init() {
        if FirebaseApp.app() != nil {
            stateSubject = CurrentValueSubject(Auth.auth().currentUser != nil)
        } else {
            stateSubject = CurrentValueSubject(false)
        }
    }

    var authenticationState: AnyPublisher<Bool, Never> {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func signInAnonymously() -> AnyPublisher<Bool, Error> {
        guard FirebaseApp.app() != nil else {
            return Fail(error: FirebaseConfigurationError.missingConfigurationFile)
                .eraseToAnyPublisher()
        }

        return Future<Bool, Error> { promise in
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    promise(.failure(error))
                } else {
                    promise(.success(true))
                }
            }
        }
        .handleEvents(receiveOutput: { [weak self] success in
            guard success else { return }
            self?.stateSubject.send(true)
        })
        .eraseToAnyPublisher()
    }
}

final class FirebaseMessagingService: NSObject, ObservableObject, MessagingDelegate {
    static let shared = FirebaseMessagingService()

    private let tokenSubject = PassthroughSubject<String, Never>()

    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func requestCurrentToken() -> AnyPublisher<String, Error> {
        guard FirebaseApp.app() != nil else {
            return Fail(error: FirebaseConfigurationError.missingConfigurationFile)
                .eraseToAnyPublisher()
        }

        return Future<String, Error> { promise in
            Messaging.messaging().token { token, error in
                if let error {
                    promise(.failure(error))
                } else if let token {
                    promise(.success(token))
                } else {
                    promise(.failure(FirebaseMessagingError.tokenUnavailable))
                }
            }
        }
        .handleEvents(receiveOutput: { [weak self] token in
            self?.tokenSubject.send(token)
        })
        .eraseToAnyPublisher()
    }

    func tokenUpdates() -> AnyPublisher<String, Never> {
        tokenSubject
            .shareReplay(1)
            .eraseToAnyPublisher()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            tokenSubject.send(token)
        }
    }
}
