import Foundation
import Combine
import CombineExt

final class AppEnvironment: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published var isAuthenticated: Bool = false

    private let authService: FirebaseAuthServicing
    private var cancellables = Set<AnyCancellable>()

    init(configuration: AppConfiguration = AppConfiguration(),
         authService: FirebaseAuthServicing = FirebaseAuthService()) {
        self.configuration = configuration
        self.authService = authService
        observeAuthentication()
    }

    func signInIfNeeded() {
        guard !isAuthenticated else { return }

        authService
            .signInAnonymously()
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success in
                self?.isAuthenticated = success
            }
            .store(in: &cancellables)
    }

    private func observeAuthentication() {
        authService.authenticationState
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \AppEnvironment.isAuthenticated, on: self)
            .store(in: &cancellables)
    }
}

struct AppConfiguration {
    let baseURL: URL
    let analyticsAPIKey: String
    let environmentName: String

    init(bundle: Bundle = .main) {
        let baseURLString = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "https://example.com"
        baseURL = URL(string: baseURLString) ?? URL(string: "https://example.com")!
        analyticsAPIKey = bundle.object(forInfoDictionaryKey: "ANALYTICS_API_KEY") as? String ?? ""
        environmentName = bundle.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String ?? "Development"
    }
}
