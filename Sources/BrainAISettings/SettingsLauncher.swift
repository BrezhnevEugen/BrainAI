import AppKit
import BrainAICore

/// Thin companion: forwards to **BrainAI.app** (in-app settings). Keeps `BrainAI Settings.app` for shortcuts / Finder.
@main
enum BrainAISettingsLauncher {
    static func main() {
        BrainAICompanionAppLauncher.openSettingsInMainApp()
        // Let NSWorkspace finish handing off to BrainAI.app before this tiny helper exits.
        Thread.sleep(forTimeInterval: 0.35)
        exit(0)
    }
}
