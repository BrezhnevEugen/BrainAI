import AppKit
import Foundation

/// Opens **BrainAI Installer.app** when it is embedded in the main bundle (`DMG_SINGLE_APP`) or lies **next to** `BrainAI.app` (flat DMG / Applications folder).
public enum BrainAIEmbeddedInstaller {
    private static let embeddedRelativePath = "Contents/Resources/BrainAIEmbedded/BrainAI Installer.app"

    public static func embeddedInstallerURL() -> URL? {
        let embedded = Bundle.main.bundleURL.appendingPathComponent(embeddedRelativePath, isDirectory: true)
        if FileManager.default.fileExists(atPath: embedded.path) {
            return embedded
        }
        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("BrainAI Installer.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }
        return nil
    }

    /// Returns `true` if the embedded installer was found and launched.
    @discardableResult
    public static func openIfPresent() -> Bool {
        guard let url = embeddedInstallerURL() else { return false }
        NSWorkspace.shared.open(url)
        return true
    }
}
