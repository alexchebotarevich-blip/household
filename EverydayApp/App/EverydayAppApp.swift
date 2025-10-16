import SwiftUI
import UIKit
import Combine
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct EverydayAppApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var roleStore: FamilyRoleStore
    @StateObject private var router: AppRouter
    @StateObject private var reminderPreferences: ReminderPreferencesStore
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        FirebaseConfigurator.configure()
        let environment = AppEnvironment()
        let roleStore = FamilyRoleStore()
        let router = AppRouter()
        let preferences = ReminderPreferencesStore.shared
        _environment = StateObject(wrappedValue: environment)
        _roleStore = StateObject(wrappedValue: roleStore)
        _router = StateObject(wrappedValue: router)
        _reminderPreferences = StateObject(wrappedValue: preferences)
        delegate.configure(router: router, roleStore: roleStore)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(environment)
                .environmentObject(roleStore)
                .environmentObject(router)
                .environmentObject(reminderPreferences)
                .environment(\.appTheme, AppTheme.default)
                .onAppear {
                    environment.signInIfNeeded()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let messagingService = FirebaseMessagingService.shared
    private var router: AppRouter?
    private var roleStore: FamilyRoleStore?
    private var cancellables = Set<AnyCancellable>()

    func configure(router: AppRouter, roleStore: FamilyRoleStore) {
        self.router = router
        self.roleStore = roleStore
        observeMessagingTokens()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseConfigurator.configure()
        UNUserNotificationCenter.current().delegate = self
        NotificationAuthorizationService.shared.refreshStatus()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleRemoteNotification(userInfo: userInfo)
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        requestMessagingToken()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("⚠️ Failed to register for remote notifications: \(error)")
        #endif
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleRemoteNotification(userInfo: userInfo)
        completionHandler(.noData)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        handleRemoteNotification(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        guard let payload = NotificationPayload(userInfo: userInfo), let router else { return }
        let allowedRoles = roleStore?.roles.map(\.id) ?? []
        DispatchQueue.main.async {
            router.handle(notification: payload, allowedRoleIDs: allowedRoles)
        }
    }

    private func observeMessagingTokens() {
        messagingService.tokenUpdates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] token in
                self?.registerFCMToken(token)
            }
            .store(in: &cancellables)
    }

    private func requestMessagingToken() {
        messagingService.requestCurrentToken()
            .sink { completion in
                if case let .failure(error) = completion {
                    #if DEBUG
                    print("⚠️ Failed to fetch FCM token: \(error)")
                    #endif
                }
            } receiveValue: { [weak self] token in
                self?.registerFCMToken(token)
            }
            .store(in: &cancellables)
    }

    private func registerFCMToken(_ token: String) {
        #if DEBUG
        print("ℹ️ Registered Firebase messaging token: \(token)")
        #endif
        // TODO: Sync token with backend when available.
    }
}
