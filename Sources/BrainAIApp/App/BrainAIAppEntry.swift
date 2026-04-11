import AppKit
import SwiftUI
import BrainAICore

// MARK: - Notifications (menu → SwiftUI)

extension Notification.Name {
    static let brainAIQuickSearch = Notification.Name("com.brainai.app.quickSearch")
    static let brainAINewNote = Notification.Name("com.brainai.app.newNote")
}

// MARK: - AppKit entry (SPM executable: SwiftUI `App`/`Scene` often creates no `NSWindow`)

@main
enum BrainAIAppMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = BrainAIApplicationDelegate.shared
        app.run()
    }
}

final class BrainAIApplicationDelegate: NSObject, NSApplicationDelegate {
    static let shared = BrainAIApplicationDelegate()

    private var window: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserNotificationService.shared.configure()
        setupMainMenu()
        // Building NSHostingController synchronously inside didFinishLaunching can starve the
        // first run-loop turns; defer so AppKit marks the app responsive and SwiftUI gets a clean first frame.
        DispatchQueue.main.async { [weak self] in
            self?.installMainWindow()
        }
    }

    private func installMainWindow() {
        let hosting = NSHostingController(rootView: BrainAIAppContentView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 1100, height: 700)
        hosting.view.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BrainAI"
        window.minSize = NSSize(width: 900, height: 600)
        window.contentViewController = hosting
        window.center()
        window.setFrameAutosaveName("BrainAIMainWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit BrainAI",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let brainItem = NSMenuItem(title: "BrainAI", action: nil, keyEquivalent: "")
        let brainMenu = NSMenu(title: "BrainAI")
        brainItem.submenu = brainMenu
        brainMenu.addItem(makeMenuItem(title: "Quick Search", action: #selector(quickSearch), key: "k"))
        brainMenu.addItem(makeMenuItem(title: "New Note", action: #selector(newNote), key: "n"))
        mainMenu.addItem(brainItem)

        NSApp.mainMenu = mainMenu
    }

    private func makeMenuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = .command
        return item
    }

    @objc private func quickSearch() {
        NotificationCenter.default.post(name: .brainAIQuickSearch, object: nil)
    }

    @objc private func newNote() {
        NotificationCenter.default.post(name: .brainAINewNote, object: nil)
    }
}
