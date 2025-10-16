import SwiftUI
import UIKit
import FirebaseCore

@main
struct EverydayAppApp: App {
    @StateObject private var environment: AppEnvironment
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        FirebaseConfigurator.configure()
        _environment = StateObject(wrappedValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(environment)
                .environment(\.appTheme, AppTheme.default)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseConfigurator.configure()
        return true
    }
}
