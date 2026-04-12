import Foundation

/// `Localizable.strings` for BrainAICore live in `BrainAI_BrainAICore.bundle` next to the executable (SPM / assembled `.app`).
public enum BrainAICoreResources {
    public static var bundle: Bundle {
        if let url = Bundle.main.url(forResource: "BrainAI_BrainAICore", withExtension: "bundle"),
           let b = Bundle(url: url) {
            return b
        }
        let adjacent = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("BrainAI_BrainAICore.bundle")
        if let b = Bundle(url: adjacent) {
            return b
        }
        return .main
    }
}
