import Foundation

/// `Localizable.strings` for BrainAICore: в упакованном `.app` бандл лежит в `Contents/Resources/` (codesign);
/// в разработке — `Bundle.module` (путь `.build/...`).
public enum BrainAICoreResources {
    public static var bundle: Bundle {
        let packaged = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/BrainAI_BrainAICore.bundle")
        if FileManager.default.fileExists(atPath: packaged.path), let b = Bundle(url: packaged) {
            return b
        }
        let atRoot = Bundle.main.bundleURL.appendingPathComponent("BrainAI_BrainAICore.bundle")
        if FileManager.default.fileExists(atPath: atRoot.path), let b = Bundle(url: atRoot) {
            return b
        }
        return Bundle.module
    }
}
