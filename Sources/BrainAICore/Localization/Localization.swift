import Foundation

// MARK: - Localization Manager

/// Centralized localization manager for BrainAI
/// Supports English, Russian, and Ukrainian
public final class L10n: Sendable {

    /// Current app locale (resolved from AppLanguage setting)
    public static var locale: Locale {
        let lang = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system
        switch lang {
        case .system: return .current
        case .en: return Locale(identifier: "en")
        case .ru: return Locale(identifier: "ru")
        case .uk: return Locale(identifier: "uk")
        }
    }

    /// Bundle identifier hint for localization lookup
    nonisolated(unsafe) private static var _bundle: Bundle = .main

    public static var bundle: Bundle {
        get { _bundle }
        set { _bundle = newValue }
    }

    // MARK: - Common

    public enum Common {
        public static var appName: String { tr("common.app_name") }
        public static var ok: String { tr("common.ok") }
        public static var cancel: String { tr("common.cancel") }
        public static var save: String { tr("common.save") }
        public static var delete: String { tr("common.delete") }
        public static var edit: String { tr("common.edit") }
        public static var close: String { tr("common.close") }
        public static var search: String { tr("common.search") }
        public static var loading: String { tr("common.loading") }
        public static var error: String { tr("common.error") }
        public static var retry: String { tr("common.retry") }
        public static var settings: String { tr("common.settings") }
        public static var done: String { tr("common.done") }
        public static var back: String { tr("common.back") }
        public static var next: String { tr("common.next") }
        public static var copy: String { tr("common.copy") }
        public static var share: String { tr("common.share") }
    }

    // MARK: - Sidebar / Navigation

    public enum Nav {
        public static var dashboard: String { tr("nav.dashboard") }
        public static var chat: String { tr("nav.chat") }
        public static var documents: String { tr("nav.documents") }
        public static var search: String { tr("nav.search") }
        public static var notes: String { tr("nav.notes") }
        public static var graph: String { tr("nav.graph") }
    }

    // MARK: - Chat

    public enum Chat {
        public static var placeholder: String { tr("chat.placeholder") }
        public static var thinking: String { tr("chat.thinking") }
        public static var send: String { tr("chat.send") }
        public static var clearHistory: String { tr("chat.clear_history") }
        public static var noMessages: String { tr("chat.no_messages") }
        public static var mode: String { tr("chat.mode") }
    }

    // MARK: - Documents

    public enum Documents {
        public static var title: String { tr("documents.title") }
        public static var add: String { tr("documents.add") }
        public static var empty: String { tr("documents.empty") }
        public static var processing: String { tr("documents.processing") }
        public static var processed: String { tr("documents.processed") }
        public static var failed: String { tr("documents.failed") }
        public static var pending: String { tr("documents.pending") }
        public static var deleteConfirm: String { tr("documents.delete_confirm") }
    }

    // MARK: - Knowledge Graph

    public enum Graph {
        public static var title: String { tr("graph.title") }
        public static var entities: String { tr("graph.entities") }
        public static var relations: String { tr("graph.relations") }
        public static var filter: String { tr("graph.filter") }
        public static var findPath: String { tr("graph.find_path") }
        public static var zoomToFit: String { tr("graph.zoom_to_fit") }
        public static var relayout: String { tr("graph.relayout") }
        public static var reload: String { tr("graph.reload") }
        public static var noData: String { tr("graph.no_data") }
        public static var selectedNode: String { tr("graph.selected_node") }
        public static var connections: String { tr("graph.connections") }
    }

    // MARK: - Settings

    public enum Settings {
        public static var title: String { tr("settings.title") }
        public static var general: String { tr("settings.general") }
        public static var providers: String { tr("settings.providers") }
        public static var server: String { tr("settings.server") }
        public static var models: String { tr("settings.models") }
        public static var workspaces: String { tr("settings.workspaces") }
        public static var advanced: String { tr("settings.advanced") }
        public static var language: String { tr("settings.language") }
        public static var theme: String { tr("settings.theme") }
        public static var checkUpdates: String { tr("settings.check_updates") }
        public static var autoUpdates: String { tr("settings.auto_updates") }
    }

    // MARK: - Server / Connection

    public enum Server {
        public static var local: String { tr("server.local") }
        public static var remote: String { tr("server.remote") }
        public static var connected: String { tr("server.connected") }
        public static var disconnected: String { tr("server.disconnected") }
        public static var connecting: String { tr("server.connecting") }
        public static var testConnection: String { tr("server.test_connection") }
        public static var latency: String { tr("server.latency") }
        public static var status: String { tr("server.status") }
        public static var start: String { tr("server.start") }
        public static var stop: String { tr("server.stop") }
        public static var restart: String { tr("server.restart") }
    }

    // MARK: - Tray

    public enum Tray {
        public static var openApp: String { tr("tray.open_app") }
        public static var quit: String { tr("tray.quit") }
        public static var running: String { tr("tray.running") }
        public static var stopped: String { tr("tray.stopped") }
        public static var model: String { tr("tray.model") }
    }

    // MARK: - Installer

    public enum Installer {
        public static var welcome: String { tr("installer.welcome") }
        public static var welcomeSubtitle: String { tr("installer.welcome_subtitle") }
        public static var components: String { tr("installer.components") }
        public static var provider: String { tr("installer.provider") }
        public static var models: String { tr("installer.models") }
        public static var download: String { tr("installer.download") }
        public static var complete: String { tr("installer.complete") }
        public static var completeMessage: String { tr("installer.complete_message") }
        public static var install: String { tr("installer.install") }
    }

    // MARK: - Errors

    public enum Errors {
        public static var networkError: String { tr("errors.network") }
        public static var unauthorized: String { tr("errors.unauthorized") }
        public static var serverUnavailable: String { tr("errors.server_unavailable") }
        public static var decodingFailed: String { tr("errors.decoding") }
        public static var unknownError: String { tr("errors.unknown") }
    }

    // MARK: - Helpers

    private static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// Formatted localized string
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, arguments: args)
    }
}
