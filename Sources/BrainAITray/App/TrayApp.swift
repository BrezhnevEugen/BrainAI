import AppKit
import SwiftUI
import BrainAICore

/// BrainAI Tray application entry point.
/// Runs as a menu bar agent (LSUIElement) with no dock icon.
@main
struct TrayApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = TrayAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Main application delegate managing the menu bar status item.
final class TrayAppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var statusMenu = NSMenu()
    private let systemMonitor = SystemMonitor()
    private let serviceOrchestrator: ServiceOrchestrator
    private let remoteConnectionManager = RemoteConnectionManager()
    private var updateTimer: Timer?
    private var ollamaRunning = false
    private var lightRAGRunning = false
    private var remoteLatency: TimeInterval = 0
    private var remoteConnected = false

    override init() {
        let ollamaManager = OllamaProcessManager(port: UInt16(AppConfiguration.shared.ollamaPort))
        self.serviceOrchestrator = ServiceOrchestrator(ollama: ollamaManager)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserNotificationService.shared.configure()
        Task {
            let status = await UserNotificationService.shared.authorizationStatus()
            if status == .notDetermined {
                _ = await UserNotificationService.shared.requestAuthorization()
            }
        }
        setupStatusItem()
        startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = Self.makeStatusBarIcon()
            button.title = "BrainAI"
            button.imagePosition = .imageLeading
            button.toolTip = "BrainAI"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        rebuildMenu()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        rebuildMenu()
        statusItem?.popUpMenu(statusMenu)
    }

    private static func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let line = NSBezierPath()
        line.lineWidth = 1.8
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        line.move(to: NSPoint(x: 4.0, y: 6.3))
        line.curve(
            to: NSPoint(x: 9.0, y: 12.4),
            controlPoint1: NSPoint(x: 4.8, y: 10.6),
            controlPoint2: NSPoint(x: 6.8, y: 12.6)
        )
        line.curve(
            to: NSPoint(x: 14.0, y: 6.8),
            controlPoint1: NSPoint(x: 11.6, y: 12.2),
            controlPoint2: NSPoint(x: 13.3, y: 10.8)
        )
        line.stroke()

        let secondLine = NSBezierPath()
        secondLine.lineWidth = 1.8
        secondLine.lineCapStyle = .round
        secondLine.move(to: NSPoint(x: 6.0, y: 5.4))
        secondLine.curve(
            to: NSPoint(x: 12.2, y: 5.5),
            controlPoint1: NSPoint(x: 7.4, y: 3.2),
            controlPoint2: NSPoint(x: 10.6, y: 3.2)
        )
        secondLine.stroke()

        for node in [
            NSRect(x: 2.7, y: 4.8, width: 3.2, height: 3.2),
            NSRect(x: 7.4, y: 11.0, width: 3.2, height: 3.2),
            NSRect(x: 12.1, y: 5.4, width: 3.2, height: 3.2),
            NSRect(x: 8.0, y: 3.1, width: 2.6, height: 2.6),
        ] {
            NSBezierPath(ovalIn: node).fill()
        }

        image.unlockFocus()
        image.isTemplate = true
        image.size = size
        image.accessibilityDescription = "BrainAI"
        return image
    }

    /// Disabled `NSMenuItem` rows are dimmed by the system on vibrant menus — use enabled + no-op for read-only rows.
    private func markInertMenuRow(_ item: NSMenuItem) {
        item.isEnabled = true
        item.action = #selector(trayInertMenuAction)
    }

    @objc private func trayInertMenuAction() {}

    /// Darken system accent colors slightly so they stay legible on light menu vibrancy.
    private func menuAccentTextColor(_ base: NSColor) -> NSColor {
        guard let rgb = base.usingColorSpace(.deviceRGB),
              let black = NSColor.black.usingColorSpace(.deviceRGB) else { return base }
        return rgb.blended(withFraction: 0.42, of: black) ?? base
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Status header
        let titleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "BrainAI",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        markInertMenuRow(titleItem)
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Service statuses (async check happens in background)
        let lightragStatus = makeStatusItem(name: "LightRAG", isRunning: lightRAGRunning)
        menu.addItem(lightragStatus)

        let ollamaStatus = makeStatusItem(name: "Ollama", isRunning: ollamaRunning)
        menu.addItem(ollamaStatus)

        // MCP server status (exposes memory to external agents)
        let mcpServer = MCPWebSocketServer.shared
        let mcpStatus = makeStatusItem(name: "MCP Server", isRunning: mcpServer.isRunning)
        menu.addItem(mcpStatus)

        if mcpServer.isRunning {
            let detailItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            detailItem.attributedTitle = NSAttributedString(
                string: "  ws://localhost:\(mcpServer.port) · \(mcpServer.activeConnections) client(s)",
                attributes: [.font: font, .foregroundColor: menuAccentTextColor(.systemGreen)]
            )
            markInertMenuRow(detailItem)
            menu.addItem(detailItem)
        }

        // Remote connection status
        if remoteConnected {
            let latencyMs = Int(remoteLatency * 1000)
            let remoteItem = makeStatusItem(name: "Remote", isRunning: true)
            menu.addItem(remoteItem)

            let latencyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rawLatency: NSColor = latencyMs < 200 ? .systemGreen : (latencyMs < 500 ? .systemYellow : .systemRed)
            let latencyColor = menuAccentTextColor(rawLatency)
            latencyItem.attributedTitle = NSAttributedString(
                string: "  Latency: \(latencyMs)ms",
                attributes: [.font: font, .foregroundColor: latencyColor]
            )
            markInertMenuRow(latencyItem)
            menu.addItem(latencyItem)
        }

        menu.addItem(NSMenuItem.separator())

        // RAM monitoring
        let stats = systemMonitor.currentStats
        menu.addItem(makeProgressItem(label: "RAM", used: stats.usedRAM, total: stats.totalRAM))
        menu.addItem(makeProgressItem(label: "Swap", used: stats.swapUsed, total: stats.swapTotal))
        menu.addItem(makeOllamaRAMItem(bytes: stats.ollamaRAM))

        menu.addItem(NSMenuItem.separator())

        // Model info
        let modelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        modelItem.attributedTitle = NSAttributedString(
            string: "Model: \(AppConfiguration.shared.generationRole.modelID)",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        markInertMenuRow(modelItem)
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())

        // Actions
        menu.addItem(NSMenuItem(title: "Open BrainAI", action: #selector(openMainUI), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit BrainAI", action: #selector(quitApp), keyEquivalent: "q"))

        // Set targets
        for item in menu.items {
            if item.action != nil {
                item.target = self
            }
        }

        statusMenu = menu
    }

    // MARK: - Menu Items

    private func makeStatusItem(name: String, isRunning: Bool) -> NSMenuItem {
        let symbol = isRunning ? "circle.fill" : "circle"
        let accent = menuAccentTextColor(isRunning ? .systemGreen : .systemRed)
        let title = "\(name): \(isRunning ? "Running" : "Stopped")"

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

        let attributed = NSMutableAttributedString()
        if let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [accent]))
            let tinted = symbolImage.withSymbolConfiguration(config)
            let attachment = NSTextAttachment()
            attachment.image = tinted
            attributed.append(NSAttributedString(attachment: attachment))
            attributed.append(NSAttributedString(string: " "))
        }

        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: mono,
            .foregroundColor: NSColor.labelColor,
        ]
        let stateAttrs: [NSAttributedString.Key: Any] = [
            .font: mono,
            .foregroundColor: accent,
        ]
        attributed.append(NSAttributedString(string: "\(name): ", attributes: nameAttrs))
        attributed.append(NSAttributedString(string: isRunning ? "Running" : "Stopped", attributes: stateAttrs))
        item.attributedTitle = attributed
        markInertMenuRow(item)

        return item
    }

    private func makeProgressItem(label: String, used: UInt64, total: UInt64) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")

        let usedGB = Double(used) / 1_073_741_824
        let totalGB = Double(total) / 1_073_741_824
        let percentage = total > 0 ? Double(used) / Double(total) : 0

        let barWidth = 15
        let filledCount = Int(percentage * Double(barWidth))
        let emptyCount = barWidth - filledCount

        let filled = String(repeating: "\u{2588}", count: filledCount)
        let empty = String(repeating: "\u{2591}", count: emptyCount)

        let rawBar: NSColor
        switch percentage {
        case ..<0.50: rawBar = .systemGreen
        case ..<0.70: rawBar = .systemYellow
        case ..<0.85: rawBar = .systemOrange
        default: rawBar = .systemRed
        }
        let color = menuAccentTextColor(rawBar)

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributed = NSMutableAttributedString()

        let labelStr = label.padding(toLength: 4, withPad: " ", startingAt: 0) + " "
        attributed.append(NSAttributedString(string: labelStr, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
        attributed.append(NSAttributedString(string: filled, attributes: [.font: font, .foregroundColor: color]))
        attributed.append(NSAttributedString(string: empty, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))

        let stats = String(format: " %.1f/%.1f GB", usedGB, totalGB)
        attributed.append(NSAttributedString(string: stats, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))

        item.attributedTitle = attributed
        markInertMenuRow(item)
        return item
    }

    private func makeOllamaRAMItem(bytes: UInt64) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let text: String
        if bytes > 0 {
            let gb = Double(bytes) / 1_073_741_824
            text = String(format: "Ollama: %.1f GB", gb)
        } else {
            text = "Ollama: not loaded"
        }

        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: bytes > 0 ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
        markInertMenuRow(item)
        return item
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        systemMonitor.update()
        checkServiceStatuses()
        rebuildMenu()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.systemMonitor.update()
            self?.checkServiceStatuses()
            self?.rebuildMenu()
        }
    }

    private func checkServiceStatuses() {
        Task {
            let previousOllama = await MainActor.run { ollamaRunning }
            let previousLightRAG = await MainActor.run { lightRAGRunning }

            let ollamaAPI = OllamaAPIClient(
                baseURL: "http://localhost:\(AppConfiguration.shared.ollamaPort)"
            )
            let isOllamaHealthy = try? await ollamaAPI.healthCheck()
            await MainActor.run {
                ollamaRunning = isOllamaHealthy == true
                rebuildMenu()
            }

            let lightragClient = LocalLightRAGClient()
            let health = try? await lightragClient.healthCheck()

            let remState = remoteConnectionManager.connectionState
            let latency = remoteConnectionManager.lastLatency
            let lightNow = health != nil

            await MainActor.run {
                if previousOllama && !ollamaRunning {
                    Task {
                        await UserNotificationService.shared.postImmediate(
                            title: L10n.ServiceNotifications.ollamaStoppedTitle,
                            body: L10n.ServiceNotifications.ollamaStoppedBody,
                            identifier: "com.brainai.tray.ollama.down"
                        )
                    }
                }
                if previousLightRAG && !lightNow {
                    Task {
                        await UserNotificationService.shared.postImmediate(
                            title: L10n.ServiceNotifications.lightragStoppedTitle,
                            body: L10n.ServiceNotifications.lightragStoppedBody,
                            identifier: "com.brainai.tray.lightrag.down"
                        )
                    }
                }

                lightRAGRunning = lightNow
                remoteConnected = remState.isConnected
                remoteLatency = latency
                rebuildMenu()
            }
        }
    }

    // MARK: - Actions

    @objc private func openMainUI() {
        if let mainApp = Self.urlForMainBrainAIAppAdjacentOrEmbedded() {
            NSWorkspace.shared.open(mainApp)
            return
        }
        if let url = URL(string: "http://localhost:9621") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Main app next to the tray bundle (flat DMG) or any ancestor named `BrainAI.app` (single-app DMG).
    private static func urlForMainBrainAIAppAdjacentOrEmbedded() -> URL? {
        var cursor = Bundle.main.bundleURL
        while cursor.path != "/" {
            if cursor.lastPathComponent == "BrainAI.app" {
                return cursor
            }
            cursor = cursor.deletingLastPathComponent()
        }
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("BrainAI.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }
        return nil
    }

    @objc private func openSettings() {
        BrainAICompanionAppLauncher.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
