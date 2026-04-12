import Foundation

// MARK: - LightRAG locale-aligned presets

/// Defaults aligned with recommended LightRAG + Ollama settings (chunking, summary language, models).
/// See project maintainer notes / LightRAG `.env` guides (e.g. nomic-embed-text ctx limits → smaller chunks).
public enum LightRAGLocalePreset {
    /// LightRAG `SUMMARY_LANGUAGE` — must match what the server expects in prompts (English / Russian / Ukrainian).
    public static func summaryLanguage(for appLanguage: AppLanguage) -> String {
        switch appLanguage {
        case .en:
            return "English"
        case .ru:
            return "Russian"
        case .uk:
            return "Ukrainian"
        case .system:
            let code = Locale.current.language.languageCode?.identifier ?? ""
            if code.hasPrefix("ru") { return "Russian" }
            if code.hasPrefix("uk") { return "Ukrainian" }
            return "English"
        }
    }

    /// Prefer **bge-m3** for RU/UA system locales; **nomic-embed-text** otherwise (lighter, universal).
    public static func defaultEmbeddingModelIDForSystemLocale() -> String {
        let code = Locale.current.language.languageCode?.identifier ?? ""
        if code.hasPrefix("ru") || code.hasPrefix("uk") {
            return "bge-m3"
        }
        return "nomic-embed-text"
    }

    /// Sensible first-run LLM for local Ollama (32 GB class); user can change in Settings.
    public static var defaultOllamaChatModelID: String { "qwen2.5:14b" }

    /// Stable with nomic-embed-text @ 8192 ctx; raise if you switch to bge-m3 and more RAM.
    public static var defaultChunkSize: Int { 800 }

    public static var defaultChunkOverlap: Int { 100 }
}
