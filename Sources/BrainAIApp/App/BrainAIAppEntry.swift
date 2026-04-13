import AppKit
import SwiftUI
import BrainAICore

// MARK: - Notifications (menu → SwiftUI)

extension Notification.Name {
    /// Открыть мастер начальной настройки (тот же сценарий, что пункт меню приложения).
    static let brainAIOpenSetupWizard = Notification.Name("com.brainai.app.openSetupWizard")
    static let brainAIQuickSearch = Notification.Name("com.brainai.app.quickSearch")
    static let brainAINewNote = Notification.Name("com.brainai.app.newNote")
    static let brainAIOpenGraph = Notification.Name("com.brainai.app.openGraph")
    static let brainAINewChat = Notification.Name("com.brainai.app.newChat")
    static let brainAIOpenSearch = Notification.Name("com.brainai.app.openSearch")
    static let brainAIOpenDocuments = Notification.Name("com.brainai.app.openDocuments")
    static let brainAIOpenSettings = Notification.Name("com.brainai.app.openSettings")
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
    private var distributedOpenSettingsObserver: NSObjectProtocol?
    private var shouldOpenSettingsAfterLaunch = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        shouldOpenSettingsAfterLaunch = ProcessInfo.processInfo.arguments.contains("--open-settings")
        UserNotificationService.shared.configure()
        setupMainMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSetupWizard),
            name: .brainAIOpenSetupWizard,
            object: nil
        )
        distributedOpenSettingsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.brainai.OpenSettings"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.focusMainWindowAndPostOpenSettings()
        }
        // Building NSHostingController synchronously inside didFinishLaunching can starve the
        // first run-loop turns; defer so AppKit marks the app responsive and SwiftUI gets a clean first frame.
        DispatchQueue.main.async { [weak self] in
            self?.installMainWindow()
        }
    }

    private func focusMainWindowAndPostOpenSettings() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .brainAIOpenSettings, object: nil)
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

        // SwiftUI после установки NSHostingController может заменить mainMenu — восстанавливаем своё меню.
        setupMainMenu()
        DispatchQueue.main.async { [weak self] in
            self?.setupMainMenu()
        }

        if shouldOpenSettingsAfterLaunch {
            shouldOpenSettingsAfterLaunch = false
            NotificationCenter.default.post(name: .brainAIOpenSettings, object: nil)
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appTitle = L10n.Common.appName

        // Первое меню в строке меню — меню приложения (как в стандартных macOS-приложениях):
        // без заголовка у первого NSMenuItem пункты «Мастер настройки» и др. не видны как часть приложения.
        let appItem = NSMenuItem()
        appItem.title = appTitle
        mainMenu.addItem(appItem)

        let appMenu = NSMenu(title: appTitle)
        appItem.submenu = appMenu

        appMenu.addItem(makeMenuItem(title: L10n.AppMenu.quickSearch, action: #selector(quickSearch), key: "k"))
        appMenu.addItem(makeMenuItem(title: L10n.AppMenu.newNote, action: #selector(newNote), key: "n"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(makeMenuItem(title: L10n.AppMenu.setupWizard, action: #selector(openSetupWizard), key: ""))
        appMenu.addItem(makeMenuItem(title: L10n.AppMenu.settings, action: #selector(openSettings), key: ","))
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: L10n.AppMenu.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        quitItem.keyEquivalentModifierMask = .command
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }

    private func makeMenuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = key.isEmpty ? [] : .command
        return item
    }

    @objc private func quickSearch() {
        NotificationCenter.default.post(name: .brainAIQuickSearch, object: nil)
    }

    @objc private func newNote() {
        NotificationCenter.default.post(name: .brainAINewNote, object: nil)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .brainAIOpenSettings, object: nil)
    }

    @objc private func openSetupWizard() {
        if BrainAIEmbeddedInstaller.openIfPresent() { return }
        let alert = NSAlert()
        alert.messageText = L10n.AppMenu.setupWizardMissingTitle
        alert.informativeText = L10n.AppMenu.setupWizardMissingBody
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Common.ok)
        alert.runModal()
    }
}
