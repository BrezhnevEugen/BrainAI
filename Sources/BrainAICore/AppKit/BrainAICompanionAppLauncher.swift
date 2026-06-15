import AppKit
import Foundation

/// Opens companion executables shipped next to the main app (same layout as the tray menu).
public enum BrainAICompanionAppLauncher {

    /// Main **BrainAI** UI app (settings live inside this process).
    public static let mainAppBundleIdentifier = "com.brainai.app"

    /// Legacy **BrainAI Settings** bundle (thin launcher → main app).
    public static let settingsBundleIdentifier = "com.brainai.settings"

    /// Menu bar companion app bundled inside BrainAI.app.
    public static let trayBundleIdentifier = "com.brainai.tray"

    /// Distributed notification: main app selects the Settings section (same user session).
    public static let distributedOpenSettingsNotification = NSNotification.Name("com.brainai.OpenSettings")

    /// Activates **BrainAI.app** and shows in-app settings (tray, menu, dashboard links, thin Settings.app).
    public static func openSettingsInMainApp() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleIdentifier)
        if let app = running.first {
            app.activate(options: [.activateAllWindows])
            DistributedNotificationCenter.default().postNotificationName(
                distributedOpenSettingsNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            return
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppBundleIdentifier) else {
            openLegacySettingsCompanionFallback()
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--open-settings"]
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if error != nil {
                openLegacySettingsCompanionFallback()
            }
        }
    }

    /// Same as `openSettingsInMainApp()` (settings are no longer a separate full UI app).
    public static func openSettings() {
        openSettingsInMainApp()
    }

    /// Starts the embedded menu bar app without activating it.
    public static func openTrayIfNeeded() {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: trayBundleIdentifier).isEmpty {
            return
        }

        let mainAppURL = urlForBrainAIMainAppAncestorOrNil(from: Bundle.main.bundleURL) ?? Bundle.main.bundleURL
        let embeddedTray = mainAppURL
            .appendingPathComponent("Contents/Resources/BrainAIEmbedded/BrainAI Tray.app", isDirectory: true)

        if FileManager.default.fileExists(atPath: embeddedTray.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [embeddedTray.path]
            try? task.run()
            return
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trayBundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
        }
    }

    private static func openLegacySettingsCompanionFallback() {
        if let mainURL = urlForBrainAIMainAppAncestorOrNil(from: Bundle.main.bundleURL) {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = ["--open-settings"]
            NSWorkspace.shared.openApplication(at: mainURL, configuration: config) { _, _ in }
            return
        }
        let parent = Bundle.main.bundleURL.deletingLastPathComponent()
        let settingsApp = parent.appendingPathComponent("BrainAI Settings.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: settingsApp.path) {
            NSWorkspace.shared.open(settingsApp)
            return
        }
        let settingsBinary = parent.appendingPathComponent("BrainAISettings")
        if FileManager.default.fileExists(atPath: settingsBinary.path) {
            let task = Process()
            task.executableURL = settingsBinary
            try? task.run()
            return
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settingsBundleIdentifier) {
            NSWorkspace.shared.open(url)
        }
    }

    /// When helpers live inside `BrainAI.app/Contents/Resources/...`, walk up to the main bundle URL.
    private static func urlForBrainAIMainAppAncestorOrNil(from bundleURL: URL) -> URL? {
        var cursor = bundleURL
        while cursor.path != "/" {
            if cursor.lastPathComponent == "BrainAI.app" {
                return cursor
            }
            cursor = cursor.deletingLastPathComponent()
        }
        return nil
    }
}
