import AppKit
import Foundation
import UserNotifications

/// Local notifications (per process). On macOS each app / helper has its own authorization.
public final class UserNotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    public static let shared = UserNotificationService()

    private override init() {
        super.init()
    }

    /// `UNUserNotificationCenter` crashes with `bundleProxyForCurrentProcess is nil` when the executable
    /// is not inside a real `.app` (e.g. SwiftPM output in `.build/.../release/`). Use packaged apps from `build-and-sign.sh`.
    public static var isNotificationCenterAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Install delegate; call once per process on the main thread at launch.
    public func configure() {
        guard Self.isNotificationCenterAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        guard Self.isNotificationCenterAvailable else { return .denied }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    public func requestAuthorization() async -> Bool {
        guard Self.isNotificationCenterAvailable else { return false }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted
        } catch {
            return false
        }
    }

    /// Posts an immediate banner if the current app is authorized.
    public func postImmediate(title: String, body: String, identifier: String = UUID().uuidString) async {
        guard Self.isNotificationCenterAvailable else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            break
        default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {}
    }

    /// Opens System Settings → Notifications (user picks BrainAI / Brain AI Tray / Settings).
    public static func openSystemNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for raw in candidates {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
