import Foundation

// MARK: - Parse `ollama list` / `ollama list --json`

enum OllamaModelInventory {
    /// Normalizes tags for comparison (e.g. `qwen2.5:14b:latest` → `qwen2.5:14b`).
    static func canonicalName(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix(":latest") {
            s.removeLast(7)
        }
        return s
    }

    /// Returns canonical model names currently reported by Ollama, or empty set if Ollama is missing or list fails.
    static func fetchInstalledCanonicalNames() async -> Set<String> {
        guard await commandExists("ollama") else { return [] }

        if let data = await runOllama(arguments: ["list", "--json"]),
           let parsed = parseListJSON(data) {
            return parsed
        }

        if let data = await runOllama(arguments: ["list", "-json"]),
           let parsed = parseListJSON(data) {
            return parsed
        }

        if let text = await runOllamaString(arguments: ["list"]) {
            return parseListTable(text)
        }

        return []
    }

    // MARK: - Parsing

    private struct ListJSONRoot: Decodable {
        let models: [ListJSONModel]
    }

    private struct ListJSONModel: Decodable {
        let name: String
    }

    private static func parseListJSON(_ data: Data) -> Set<String>? {
        if let root = try? JSONDecoder().decode(ListJSONRoot.self, from: data) {
            return Set(root.models.map { canonicalName($0.name) })
        }
        if let arr = try? JSONDecoder().decode([ListJSONModel].self, from: data) {
            return Set(arr.map { canonicalName($0.name) })
        }
        return nil
    }

    /// Plain `ollama list` table: skip header, use first column (NAME).
    static func parseListTable(_ output: String) -> Set<String> {
        var result = Set<String>()
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return result }

        for (index, line) in lines.enumerated() {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if index == 0, trimmed.uppercased().contains("NAME") { continue }

            let parts = trimmed.split { $0.isWhitespace }
            guard let first = parts.first else { continue }
            let name = String(first)
            if name == "NAME" || name.hasPrefix("---") { continue }
            result.insert(canonicalName(name))
        }
        return result
    }

    // MARK: - Process helpers

    private static func commandExists(_ command: String) async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [command]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    private static func resolveExecutable(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty {
                return path
            }
        } catch {
            // fall through
        }
        return "/usr/local/bin/\(command)"
    }

    private static func runOllama(arguments: [String]) async -> Data? {
        await Task.detached {
            let path = resolveExecutable("ollama")
            guard FileManager.default.isExecutableFile(atPath: path) else { return nil as Data? }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return pipe.fileHandleForReading.readDataToEndOfFile()
            } catch {
                return nil
            }
        }.value
    }

    private static func runOllamaString(arguments: [String]) async -> String? {
        guard let data = await runOllama(arguments: arguments) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
