import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class NotificationAuthorizationService: ObservableObject {
    static let shared = NotificationAuthorizationService()

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter
    private let messagingService: FirebaseMessagingService

    init(center: UNUserNotificationCenter = .current(),
         messagingService: FirebaseMessagingService = .shared) {
        self.center = center
        self.messagingService = messagingService
    }

    func refreshStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.status = settings.authorizationStatus
            }
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound]) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: options) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if let error {
                        #if DEBUG
                        print("⚠️ Notification authorization failed: \(error)")
                        #endif
                    }
                    self?.status = granted ? .authorized : .denied
                    if granted {
                        self?.messagingService.registerForRemoteNotifications()
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
