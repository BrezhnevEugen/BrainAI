import AppKit
import Foundation

/// Opens **BrainAI Installer.app** when it is shipped inside the main bundle (`DMG_SINGLE_APP` layout).
public enum BrainAIEmbeddedInstaller {
    private static let embeddedRelativePath = "Contents/Resources/BrainAIEmbedded/BrainAI Installer.app"

    public static func embeddedInstallerURL() -> URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent(embeddedRelativePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Returns `true` if the embedded installer was found and launched.
    @discardableResult
    public static func openIfPresent() -> Bool {
        guard let url = embeddedInstallerURL() else { return false }
        NSWorkspace.shared.open(url)
        return true
    }
}
