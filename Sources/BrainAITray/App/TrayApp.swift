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
    private let systemMonitor = SystemMonitor()
    private let serviceOrchestrator: ServiceOrchestrator
    private var updateTimer: Timer?

    override init() {
        let ollamaManager = OllamaProcessManager(port: UInt16(AppConfiguration.shared.ollamaPort))
        self.serviceOrchestrator = ServiceOrchestrator(ollama: ollamaManager)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "BrainAI")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Status header
        let titleItem = NSMenuItem(title: "BrainAI", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "BrainAI",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13)
            ]
        )
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Service statuses
        let lightragStatus = makeStatusItem(name: "LightRAG", isRunning: false)
        menu.addItem(lightragStatus)

        let ollamaStatus = makeStatusItem(name: "Ollama", isRunning: false)
        menu.addItem(ollamaStatus)

        menu.addItem(NSMenuItem.separator())

        // RAM monitoring
        let stats = systemMonitor.currentStats
        menu.addItem(makeProgressItem(label: "RAM", used: stats.usedRAM, total: stats.totalRAM))
        menu.addItem(makeProgressItem(label: "Swap", used: stats.swapUsed, total: stats.swapTotal))
        menu.addItem(makeOllamaRAMItem(bytes: stats.ollamaRAM))

        menu.addItem(NSMenuItem.separator())

        // Model info
        let modelItem = NSMenuItem(title: "Model: \(AppConfiguration.shared.generationRole.modelID)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
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

        statusItem?.menu = menu
    }

    // MARK: - Menu Items

    private func makeStatusItem(name: String, isRunning: Bool) -> NSMenuItem {
        let symbol = isRunning ? "circle.fill" : "circle"
        let color: NSColor = isRunning ? .systemGreen : .systemRed
        let title = "\(name): \(isRunning ? "Running" : "Stopped")"

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

        let attributed = NSMutableAttributedString()
        if let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let tinted = symbolImage.withSymbolConfiguration(.init(pointSize: 10, weight: .regular))
            let attachment = NSTextAttachment()
            attachment.image = tinted
            attributed.append(NSAttributedString(attachment: attachment))
            attributed.append(NSAttributedString(string: " "))
        }

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: color
        ]
        attributed.append(NSAttributedString(string: title, attributes: textAttrs))
        item.attributedTitle = attributed
        item.isEnabled = false

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

        let color: NSColor
        switch percentage {
        case ..<0.50: color = .systemGreen
        case ..<0.70: color = .systemYellow
        case ..<0.85: color = .systemOrange
        default: color = .systemRed
        }

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributed = NSMutableAttributedString()

        let labelStr = String(format: "%-4s ", label.padding(toLength: 4, withPad: " ", startingAt: 0))
        attributed.append(NSAttributedString(string: labelStr, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
        attributed.append(NSAttributedString(string: filled, attributes: [.font: font, .foregroundColor: color]))
        attributed.append(NSAttributedString(string: empty, attributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]))

        let stats = String(format: " %.1f/%.1f GB", usedGB, totalGB)
        attributed.append(NSAttributedString(string: stats, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))

        item.attributedTitle = attributed
        item.isEnabled = false
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
            .foregroundColor: bytes > 0 ? NSColor.labelColor : NSColor.tertiaryLabelColor
        ])
        item.isEnabled = false
        return item
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        systemMonitor.update()
        rebuildMenu()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.systemMonitor.update()
            self?.rebuildMenu()
        }
    }

    // MARK: - Actions

    @objc private func openMainUI() {
        // TODO: Launch BrainAIApp or open WebUI in browser
        if let url = URL(string: "http://localhost:9621") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettings() {
        // TODO: Launch BrainAISettings app
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
