import Foundation

// MARK: - Localization Manager

/// Centralized localization manager for BrainAI
/// Supports English, Russian, and Ukrainian
public final class L10n: Sendable {

    /// Current app locale (resolved from `AppConfiguration.language`)
    public static var locale: Locale {
        switch AppConfiguration.shared.language {
        case .system: return .current
        case .en: return Locale(identifier: "en")
        case .ru: return Locale(identifier: "ru")
        case .uk: return Locale(identifier: "uk")
        case .de: return Locale(identifier: "de")
        case .fr: return Locale(identifier: "fr")
        case .it: return Locale(identifier: "it")
        case .es: return Locale(identifier: "es")
        case .pl: return Locale(identifier: "pl")
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .ja: return Locale(identifier: "ja")
        }
    }

    /// Base bundle that contains `en.lproj`, `ru.lproj`, … (defaults to `BrainAI_BrainAICore.bundle`).
    nonisolated(unsafe) private static var _resourceBase: Bundle?

    public static var bundle: Bundle {
        get { _resourceBase ?? BrainAICoreResources.bundle }
        set { _resourceBase = newValue }
    }

    private static func resolvedLanguageCode() -> String {
        switch AppConfiguration.shared.language {
        case .system:
            if let first = Locale.preferredLanguages.first {
                if first.hasPrefix("zh") { return "zh-Hans" }
                return String(first.prefix(while: { $0 != "-" && $0 != "_" }))
            }
            return "en"
        case .en: return "en"
        case .ru: return "ru"
        case .uk: return "uk"
        case .de: return "de"
        case .fr: return "fr"
        case .it: return "it"
        case .es: return "es"
        case .pl: return "pl"
        case .zhHans: return "zh-Hans"
        case .ja: return "ja"
        }
    }

    private static func localizedStringsBundle() -> Bundle {
        let base = bundle
        let code = resolvedLanguageCode()
        if let url = base.url(forResource: code, withExtension: "lproj"),
           let b = Bundle(url: url) {
            return b
        }
        let short = String(code.prefix(while: { $0 != "-" && $0 != "_" }))
        if short != code, let url = base.url(forResource: short, withExtension: "lproj"),
           let b = Bundle(url: url) {
            return b
        }
        if let url = base.url(forResource: "en", withExtension: "lproj"),
           let b = Bundle(url: url) {
            return b
        }
        return base
    }

    // MARK: - Common

    public enum Common {
        public static var appName: String { tr("common.app_name") }
        /// Stitch sidebar subtitle under the wordmark.
        public static var brandTagline: String { tr("common.brand_tagline") }
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

    public enum Sidebar {
        public static var localInstance: String { tr("sidebar.local_instance") }
    }

    public enum Nav {
        public static var dashboard: String { tr("nav.dashboard") }
        public static var chat: String { tr("nav.chat") }
        public static var documents: String { tr("nav.documents") }
        public static var search: String { tr("nav.search") }
        public static var notes: String { tr("nav.notes") }
        public static var wiki: String { "Wiki" }
        public static var graph: String { tr("nav.graph") }
        public static var settings: String { tr("nav.settings") }
        /// Короткая подпись для сайдбара и панелей (меню приложения — `AppMenu.setupWizard`).
        public static var setupWizard: String { tr("nav.setup_wizard") }
    }

    // MARK: - Dashboard

    /// Main-window chrome (Stitch top bar).
    public enum Chrome {
        public static var archiveSearchPlaceholder: String { tr("chrome.archive_search_placeholder") }
    }

    public enum Dashboard {
        public static var heroTitle: String { tr("dashboard.hero_title") }
        public static var heroSubtitle: String { tr("dashboard.hero_subtitle") }
        public static var exportGraph: String { tr("dashboard.export_graph") }
        public static var newEntry: String { tr("dashboard.new_entry") }
        public static var overview: String { tr("dashboard.overview") }
        public static var activeWorkspace: String { tr("dashboard.active_workspace") }
        public static var serviceStatus: String { tr("dashboard.service_status") }
        public static var recentActivity: String { tr("dashboard.recent_activity") }
        public static var quickActions: String { tr("dashboard.quick_actions") }
        public static var providerRoles: String { tr("dashboard.provider_roles") }
        public static var workspaceNone: String { tr("dashboard.workspace.none") }
        public static var workspaceActive: String { tr("dashboard.workspace.active") }
        public static var workspaceInactive: String { tr("dashboard.workspace.inactive") }
        public static var serviceRunning: String { tr("dashboard.service.running") }
        public static var serviceStopped: String { tr("dashboard.service.stopped") }
        public static var serviceError: String { tr("dashboard.service.error") }
        public static var serviceUnknown: String { tr("dashboard.service.unknown") }
        public static var statEntities: String { tr("dashboard.stat.entities") }
        public static var statRelations: String { tr("dashboard.stat.relations") }
        public static var statDocuments: String { tr("dashboard.stat.documents") }
        public static var statWorkspaces: String { tr("dashboard.stat.workspaces") }
        public static var quickSearchPlaceholder: String { tr("dashboard.quick_search_placeholder") }
        public static var actionNewNote: String { tr("dashboard.action.new_note") }
        public static var actionInsertDocument: String { tr("dashboard.action.insert_document") }
        public static var actionAskQuestion: String { tr("dashboard.action.ask_question") }
        public static var actionBrowseGraph: String { tr("dashboard.action.browse_graph") }
        public static var activityDocumentInserted: String { tr("dashboard.activity.document_inserted") }
        public static var activityQueryExecuted: String { tr("dashboard.activity.query_executed") }
        public static var activitySampleML: String { tr("dashboard.activity.sample_ml") }
        public static var activitySampleTransformers: String { tr("dashboard.activity.sample_transformers") }
        public static var activitySampleReport: String { tr("dashboard.activity.sample_report") }
        public static var activitySampleSummarize: String { tr("dashboard.activity.sample_summarize") }
        public static var timeJustNow: String { tr("dashboard.time.just_now") }
        public static func timeMinutesAgo(_ n: Int) -> String { tr("dashboard.time.minutes_ago", n) }
        public static func timeHoursAgo(_ n: Int) -> String { tr("dashboard.time.hours_ago", n) }
        public static func timeDaysAgo(_ n: Int) -> String { tr("dashboard.time.days_ago", n) }
        public static var serviceNameOllama: String { tr("dashboard.service_name.ollama") }
        public static var serviceNameLightRAG: String { tr("dashboard.service_name.lightrag") }

        public static var chromeOverview: String { tr("dashboard.chrome.overview") }
        public static var chromeOllamaOn: String { tr("dashboard.chrome.ollama_on") }
        public static var chromeOllamaOff: String { tr("dashboard.chrome.ollama_off") }
        public static var chromeLightRAGOn: String { tr("dashboard.chrome.lightrag_on") }
        public static var chromeLightRAGOff: String { tr("dashboard.chrome.lightrag_off") }
        public static var chromeNewChat: String { tr("dashboard.chrome.new_chat") }
        public static var chromeIndexFolder: String { tr("dashboard.chrome.index_folder") }
        public static var metricTagTotal: String { tr("dashboard.metric.tag.total") }
        public static var metricTagLinked: String { tr("dashboard.metric.tag.linked") }
        public static var metricTagStored: String { tr("dashboard.metric.tag.stored") }
        public static var metricTagActive: String { tr("dashboard.metric.tag.active") }
        public static var metricCaptionEntities: String { tr("dashboard.metric.caption.entities") }
        public static var metricCaptionRelations: String { tr("dashboard.metric.caption.relations") }
        public static var metricCaptionDocuments: String { tr("dashboard.metric.caption.documents") }
        public static var metricCaptionWorkspaces: String { tr("dashboard.metric.caption.workspaces") }
        public static var workspaceSectionActive: String { tr("dashboard.workspace.section_active") }
        public static var workspaceResume: String { tr("dashboard.workspace.resume") }
        public static var workspaceSettingsLink: String { tr("dashboard.workspace.settings_link") }
        public static var workspaceBlurb: String { tr("dashboard.workspace.blurb") }
        public static var workspaceBlurbEmpty: String { tr("dashboard.workspace.blurb_empty") }
        public static var activityViewFullLog: String { tr("dashboard.activity.view_full_log") }
        public static var footerE2E: String { tr("dashboard.footer.e2e") }
        public static var footerLocalInference: String { tr("dashboard.footer.local_inference") }
        public static var footerSQLite: String { tr("dashboard.footer.sqlite") }
        public static func timeShortMinutes(_ n: Int) -> String { tr("dashboard.time.short_minutes", n) }
        public static func timeShortHours(_ n: Int) -> String { tr("dashboard.time.short_hours", n) }

        public static func providerRole(_ id: String) -> String {
            switch id {
            case "embedding": return tr("dashboard.role.embedding")
            case "extraction": return tr("dashboard.role.extraction")
            case "reranking": return tr("dashboard.role.reranking")
            case "generation": return tr("dashboard.role.generation")
            default: return id
            }
        }
    }

    // MARK: - App menu (main menu)

    public enum AppMenu {
        public static var quit: String { tr("app.menu.quit") }
        public static var sectionTitle: String { tr("app.menu.section") }
        public static var quickSearch: String { tr("app.menu.quick_search") }
        public static var newNote: String { tr("app.menu.new_note") }
        public static var settings: String { tr("app.menu.settings") }
        public static var setupWizard: String { tr("app.menu.setup_wizard") }
        public static var setupWizardMissingTitle: String { tr("app.menu.setup_wizard_missing_title") }
        public static var setupWizardMissingBody: String { tr("app.menu.setup_wizard_missing_body") }
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
        public static var languageFollowSystem: String { tr("settings.language.follow_system") }
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

    // MARK: - Settings / Notifications

    public enum SettingsNotifications {
        public static var section: String { tr("settings.notifications.section") }
        public static var statusLabel: String { tr("settings.notifications.status_label") }
        public static var statusNotDetermined: String { tr("settings.notifications.status.not_determined") }
        public static var statusDenied: String { tr("settings.notifications.status.denied") }
        public static var statusAuthorized: String { tr("settings.notifications.status.authorized") }
        public static var statusProvisional: String { tr("settings.notifications.status.provisional") }
        public static var statusUnknown: String { tr("settings.notifications.status.unknown") }
        public static var statusUnpackagedBinary: String { tr("settings.notifications.status.unpackaged") }
        public static var allowButton: String { tr("settings.notifications.allow") }
        public static var openPrefsButton: String { tr("settings.notifications.open_prefs") }
        public static var sendTestButton: String { tr("settings.notifications.send_test") }
        public static var helpTray: String { tr("settings.notifications.help_tray") }
        public static var helpDenied: String { tr("settings.notifications.help_denied") }
        public static var testTitle: String { tr("settings.notifications.test.title") }
        public static var testBody: String { tr("settings.notifications.test.body") }
    }

    public enum ServiceNotifications {
        public static var ollamaStoppedTitle: String { tr("notifications.ollama_stopped.title") }
        public static var ollamaStoppedBody: String { tr("notifications.ollama_stopped.body") }
        public static var lightragStoppedTitle: String { tr("notifications.lightrag_stopped.title") }
        public static var lightragStoppedBody: String { tr("notifications.lightrag_stopped.body") }
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
        NSLocalizedString(key, tableName: "Localizable", bundle: localizedStringsBundle(), value: key, comment: "")
    }

    /// Formatted localized string
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: "Localizable", bundle: localizedStringsBundle(), value: key, comment: "")
        return withVaList(args) {
            NSString(format: format, locale: locale, arguments: $0) as String
        }
    }
}
