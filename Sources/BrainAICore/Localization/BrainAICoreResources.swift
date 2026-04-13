import Foundation

/// `Localizable.strings` for BrainAICore ship inside the SwiftPM **module** resource bundle (`Bundle.module`),
/// not in `Bundle.main` (the `.app` wrapper has no `en.lproj` for these keys).
public enum BrainAICoreResources {
    public static var bundle: Bundle {
        Bundle.module
    }
}
