import Foundation
import Observation
import Sparkle

// MARK: - Sparkle Update Manager

/// Manages application auto-updates via Sparkle framework
@Observable
public final class SparkleUpdateManager: NSObject, @unchecked Sendable {

    /// Whether an update check is in progress
    public var isCheckingForUpdates = false

    /// Whether a new update is available
    public var updateAvailable = false

    /// Current app version string
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Build number
    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Whether automatic update checks are enabled
    public var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Interval between automatic checks (in seconds)
    public var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    /// The underlying SPUStandardUpdaterController
    private let updaterController: SPUStandardUpdaterController

    private let lock = NSLock()

    // MARK: - Initialization

    /// Initialize with default appcast URL
    public override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    // MARK: - Public API

    /// Check for updates manually
    public func checkForUpdates() {
        lock.lock()
        isCheckingForUpdates = true
        lock.unlock()

        updaterController.checkForUpdates(nil)

        // Reset checking state after a delay (Sparkle handles UI)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.isCheckingForUpdates = false
            self.lock.unlock()
        }
    }

    /// Can check for updates (not already in progress)
    public var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// Start the updater if not already started
    public func startUpdater() {
        if !updaterController.updater.sessionInProgress {
            // Updater was started in init via startingUpdater: true
        }
    }

    // MARK: - Configuration

    /// Default appcast URL for BrainAI releases
    public static let defaultAppcastURL = "https://github.com/BrainAI-App/BrainAI/releases/latest/download/appcast.xml"

    /// Configure default update settings
    /// Note: Set the appcast URL via SUFeedURL key in Info.plist
    public func configureDefaults() {
        // Check for updates every 24 hours
        updaterController.updater.updateCheckInterval = 86400

        // Allow automatic downloading of updates
        updaterController.updater.automaticallyDownloadsUpdates = false
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// A SwiftUI view that provides a "Check for Updates" button
public struct CheckForUpdatesView: View {
    @Environment(SparkleUpdateManager.self) private var updateManager

    public init() {}

    public var body: some View {
        Button("Check for Updates...") {
            updateManager.checkForUpdates()
        }
        .disabled(!updateManager.canCheckForUpdates)
    }
}

/// Menu bar item for update checking
public struct UpdateMenuCommands: Commands {
    private let updateManager: SparkleUpdateManager

    public init(updateManager: SparkleUpdateManager) {
        self.updateManager = updateManager
    }

    public var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                updateManager.checkForUpdates()
            }
            .disabled(!updateManager.canCheckForUpdates)
        }
    }
}
