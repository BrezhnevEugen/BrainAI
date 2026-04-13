import Foundation

/// Strings for BrainAI Installer (`Localizable.strings` в SPM-модуле; в `.app` — `Contents/Resources/BrainAI_BrainAIInstaller.bundle`).
enum InstallerL10n {

    private static let installerResourcesBundle: Bundle = {
        let packaged = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/BrainAI_BrainAIInstaller.bundle")
        if FileManager.default.fileExists(atPath: packaged.path), let b = Bundle(url: packaged) {
            return b
        }
        let atRoot = Bundle.main.bundleURL.appendingPathComponent("BrainAI_BrainAIInstaller.bundle")
        if FileManager.default.fileExists(atPath: atRoot.path), let b = Bundle(url: atRoot) {
            return b
        }
        return Bundle.module
    }()

    /// SPM resource bundles often ship without `CFBundleLocalizations`. Then `NSLocalizedString(..., bundle: .module)`
    /// keeps the development language (en) even when the system is `ru`. Resolve a concrete `.lproj` inside the module bundle.
    private static let stringsBundle: Bundle = {
        let base = installerResourcesBundle
        var seen = Set<String>()
        var codes: [String] = []
        for id in Locale.preferredLanguages {
            var parts: [String] = [id]
            if let dash = id.firstIndex(of: "-") {
                parts.append(String(id[..<dash]))
            }
            for p in parts where !p.isEmpty {
                if seen.insert(p).inserted {
                    codes.append(p)
                }
            }
        }
        for code in codes {
            if let path = base.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        if let path = base.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return base
    }()

    private static func lookup(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: stringsBundle, value: key, comment: "")
    }

    private static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: lookup(key), locale: Locale.current, arguments: args)
    }

    // MARK: - Steps (stepper)

    enum Step {
        static var welcome: String { lookup("installer.step.welcome") }
        static var components: String { lookup("installer.step.components") }
        static var provider: String { lookup("installer.step.provider") }
        static var models: String { lookup("installer.step.models") }
        static var install: String { lookup("installer.step.install") }
        static var complete: String { lookup("installer.step.complete") }
    }

    // MARK: - Navigation

    enum Nav {
        static var back: String { lookup("installer.nav.back") }
        static var `continue`: String { lookup("installer.nav.continue") }
        static var done: String { lookup("installer.nav.done") }
        static var openBrainAI: String { lookup("installer.nav.open_brainai") }
        static var openSettings: String { lookup("installer.nav.open_settings") }
    }

    // MARK: - Welcome

    enum Welcome {
        static var title: String { lookup("installer.welcome.title") }
        static var subtitle: String { lookup("installer.welcome.subtitle") }
        static var itemLightRAGTitle: String { lookup("installer.welcome.item.lightrag.title") }
        static var itemLightRAGDesc: String { lookup("installer.welcome.item.lightrag.desc") }
        static var itemOllamaTitle: String { lookup("installer.welcome.item.ollama.title") }
        static var itemOllamaDesc: String { lookup("installer.welcome.item.ollama.desc") }
        static var itemModelsTitle: String { lookup("installer.welcome.item.models.title") }
        static var itemModelsDesc: String { lookup("installer.welcome.item.models.desc") }
        static func macOSVersion(_ version: String) -> String {
            format("installer.welcome.macos", version)
        }
        static func ramGB(_ gb: UInt64) -> String {
            format("installer.welcome.ram_gb", gb)
        }
    }

    // MARK: - Components

    enum Components {
        static var title: String { lookup("installer.components.title") }
        static var subtitle: String { lookup("installer.components.subtitle") }
        static var coreTitle: String { lookup("installer.components.core.title") }
        static var coreDesc: String { lookup("installer.components.core.desc") }
        static var lightragTitle: String { lookup("installer.components.lightrag.title") }
        static var lightragDesc: String { lookup("installer.components.lightrag.desc") }
        static var ollamaTitle: String { lookup("installer.components.ollama.title") }
        static var ollamaDesc: String { lookup("installer.components.ollama.desc") }
        static var sampleTitle: String { lookup("installer.components.sample.title") }
        static var sampleDesc: String { lookup("installer.components.sample.desc") }
        static var estimatedPrefix: String { lookup("installer.components.estimated_prefix") }
        static var detectedLabel: String { lookup("installer.components.detected_label") }
        static var required: String { lookup("installer.components.required") }
        static var ollamaInstalled: String { lookup("installer.components.ollama_installed") }
        static var sizeCore: String { lookup("installer.components.size.core") }
        static var sizeLightrag: String { lookup("installer.components.size.lightrag") }
        static var sizeOllama: String { lookup("installer.components.size.ollama") }
        static var sizeSample: String { lookup("installer.components.size.sample") }
        static var badgePython: String { lookup("installer.components.badge.python") }
        static var badgeOllama: String { lookup("installer.components.badge.ollama") }
        static var badgeHomebrew: String { lookup("installer.components.badge.homebrew") }
    }

    // MARK: - Provider

    enum Provider {
        static var title: String { lookup("installer.provider.title") }
        static var subtitle: String { lookup("installer.provider.subtitle") }
        static var choiceOllama: String { lookup("installer.provider.choice.ollama") }
        static var choiceOpenAI: String { lookup("installer.provider.choice.openai") }
        static var choiceAnthropic: String { lookup("installer.provider.choice.anthropic") }
        static var choiceSkip: String { lookup("installer.provider.choice.skip") }
        static var descOllama: String { lookup("installer.provider.desc.ollama") }
        static var descOpenAI: String { lookup("installer.provider.desc.openai") }
        static var descAnthropic: String { lookup("installer.provider.desc.anthropic") }
        static var descSkip: String { lookup("installer.provider.desc.skip") }
        static var openAIKeyTitle: String { lookup("installer.provider.openai_key") }
        static var anthropicKeyTitle: String { lookup("installer.provider.anthropic_key") }
        static var getAPIKey: String { lookup("installer.provider.get_api_key") }
        static var keychainNote: String { lookup("installer.provider.keychain_note") }
        static var placeholderOpenAI: String { lookup("installer.provider.placeholder.openai") }
        static var placeholderAnthropic: String { lookup("installer.provider.placeholder.anthropic") }
    }

    // MARK: - Models

    enum Models {
        static var title: String { lookup("installer.models.title") }
        static func ramHint(gb: UInt64) -> String {
            format("installer.models.ram_hint", gb)
        }
        static var scanning: String { lookup("installer.models.scanning") }
        static var scanHint: String { lookup("installer.models.scan_hint") }
        static var languageSection: String { lookup("installer.models.language_section") }
        static var recommended: String { lookup("installer.models.recommended") }
        static var installed: String { lookup("installer.models.installed") }
        static func sizeLine(_ size: String) -> String {
            format("installer.models.size_line", size)
        }
        static var noDownload: String { lookup("installer.models.no_download") }
        static func requiresRAM(_ ram: String) -> String {
            format("installer.models.requires_ram", ram)
        }
        static var embeddingSubInstalled: String { lookup("installer.models.embedding.sub.installed") }
        static var embeddingSubPending: String { lookup("installer.models.embedding.sub.pending") }
        static var approxDownload: String { lookup("installer.models.approx_download") }
        static var appNote: String { lookup("installer.models.app_note") }
        static var plannedSteps: String { lookup("installer.models.planned_steps") }
        static var nothingToRun: String { lookup("installer.models.nothing_to_run") }
        static var qwen7b: String { lookup("installer.models.qwen_7b") }
        static var qwen14b: String { lookup("installer.models.qwen_14b") }
        static var qwen32b: String { lookup("installer.models.qwen_32b") }
        static var size45: String { lookup("installer.models.size.45gb") }
        static var size9: String { lookup("installer.models.size.9gb") }
        static var size20: String { lookup("installer.models.size.20gb") }
        static var ram8: String { lookup("installer.models.ram.8gb") }
        static var ram16: String { lookup("installer.models.ram.16gb") }
        static var ram32: String { lookup("installer.models.ram.32gb") }
        static var peakRam7b: String { lookup("installer.models.peak_ram.7b") }
        static var peakRam14b: String { lookup("installer.models.peak_ram.14b") }
        static var peakRam32b: String { lookup("installer.models.peak_ram.32b") }
        static var peakRamEmbed: String { lookup("installer.models.peak_ram.embed") }
        static var ramDisclaimer: String { lookup("installer.models.ram_disclaimer") }
    }

    // MARK: - Download / tasks

    enum Download {
        static var title: String { lookup("installer.download.title") }
        static var waiting: String { lookup("installer.download.waiting") }
        static var success: String { lookup("installer.download.success") }
        static func step(current: Int, total: Int) -> String {
            format("installer.download.step", current, total)
        }
        static var statusWaiting: String { lookup("installer.download.status.waiting") }
        static var statusCompleted: String { lookup("installer.download.status.completed") }
        static var retry: String { lookup("installer.download.retry") }
    }

    enum Task {
        static var pythonName: String { lookup("installer.task.python.name") }
        static var pythonDesc: String { lookup("installer.task.python.desc") }
        static var lightragName: String { lookup("installer.task.lightrag.name") }
        static var lightragDesc: String { lookup("installer.task.lightrag.desc") }
        static var ollamaName: String { lookup("installer.task.ollama.name") }
        static var ollamaDesc: String { lookup("installer.task.ollama.desc") }
        static func llmName(model: String) -> String {
            format("installer.task.llm.name", model)
        }
        static var llmDesc: String { lookup("installer.task.llm.desc") }
        static var embedName: String { lookup("installer.task.embed.name") }
        static var embedDesc: String { lookup("installer.task.embed.desc") }
        static var sampleName: String { lookup("installer.task.sample.name") }
        static var sampleDesc: String { lookup("installer.task.sample.desc") }
    }

    // MARK: - Complete

    enum Complete {
        static var titleOk: String { lookup("installer.complete.title.ok") }
        static var titleWarn: String { lookup("installer.complete.title.warn") }
        static var bodyOk: String { lookup("installer.complete.body.ok") }
        static var bodyWarn: String { lookup("installer.complete.body.warn") }
        static var launchLogin: String { lookup("installer.complete.launch_login") }
        static var coreLabel: String { lookup("installer.complete.core") }
        static var lightragLabel: String { lookup("installer.complete.lightrag") }
        static var ollamaLabel: String { lookup("installer.complete.ollama") }
    }

    // MARK: - Disk space (estimated)

    enum DiskSpace {
        static func gigabytes(_ value: Double) -> String {
            format("installer.diskspace.gb", value)
        }
        static func megabytes(_ value: Int) -> String {
            format("installer.diskspace.mb", value)
        }
    }

    // MARK: - Errors

    enum ErrorMessage {
        static var homebrewOllama: String { lookup("installer.error.homebrew_ollama") }
    }
}
