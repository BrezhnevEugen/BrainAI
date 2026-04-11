import Foundation
import os.signpost

// MARK: - Performance Tracing

/// Unified performance tracing via os_signpost for Instruments integration
public enum BrainAITrace {

    // MARK: - Signpost Logs

    private static let queryLog = OSLog(subsystem: "com.brainai.app", category: "Query")
    private static let insertLog = OSLog(subsystem: "com.brainai.app", category: "Insert")
    private static let graphLog = OSLog(subsystem: "com.brainai.app", category: "Graph")
    private static let networkLog = OSLog(subsystem: "com.brainai.app", category: "Network")
    private static let ollamaLog = OSLog(subsystem: "com.brainai.app", category: "Ollama")
    private static let mcpLog = OSLog(subsystem: "com.brainai.app", category: "MCP")
    private static let startupLog = OSLog(subsystem: "com.brainai.app", category: "Startup")

    // MARK: - Signpost IDs

    public static func signpostID(for log: OSLog) -> OSSignpostID {
        OSSignpostID(log: log)
    }

    // MARK: - Query Tracing

    public static func beginQuery(_ question: String) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: queryLog)
        os_signpost(.begin, log: queryLog, name: "RAG Query", signpostID: id, "question: %{public}s", question)
        return (queryLog, id)
    }

    public static func endQuery(_ context: (OSLog, OSSignpostID), resultLength: Int) {
        os_signpost(.end, log: context.0, name: "RAG Query", signpostID: context.1, "result_length: %d", resultLength)
    }

    // MARK: - Insert Tracing

    public static func beginInsert(textLength: Int) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: insertLog)
        os_signpost(.begin, log: insertLog, name: "Text Insert", signpostID: id, "text_length: %d", textLength)
        return (insertLog, id)
    }

    public static func endInsert(_ context: (OSLog, OSSignpostID)) {
        os_signpost(.end, log: context.0, name: "Text Insert", signpostID: context.1)
    }

    // MARK: - Graph Layout Tracing

    public static func beginGraphLayout(nodeCount: Int) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: graphLog)
        os_signpost(.begin, log: graphLog, name: "Graph Layout", signpostID: id, "nodes: %d", nodeCount)
        return (graphLog, id)
    }

    public static func endGraphLayout(_ context: (OSLog, OSSignpostID), iterations: Int) {
        os_signpost(.end, log: context.0, name: "Graph Layout", signpostID: context.1, "iterations: %d", iterations)
    }

    public static func beginGraphLoad() -> (OSLog, OSSignpostID) {
        let id = signpostID(for: graphLog)
        os_signpost(.begin, log: graphLog, name: "Graph Load", signpostID: id)
        return (graphLog, id)
    }

    public static func endGraphLoad(_ context: (OSLog, OSSignpostID), entities: Int, edges: Int) {
        os_signpost(.end, log: context.0, name: "Graph Load", signpostID: context.1, "entities: %d, edges: %d", entities, edges)
    }

    // MARK: - Network Tracing

    public static func beginHTTPRequest(method: String, url: String) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: networkLog)
        os_signpost(.begin, log: networkLog, name: "HTTP Request", signpostID: id, "%{public}s %{public}s", method, url)
        return (networkLog, id)
    }

    public static func endHTTPRequest(_ context: (OSLog, OSSignpostID), statusCode: Int, bytes: Int) {
        os_signpost(.end, log: context.0, name: "HTTP Request", signpostID: context.1, "status: %d, bytes: %d", statusCode, bytes)
    }

    // MARK: - Ollama Tracing

    public static func beginOllamaGenerate(model: String) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: ollamaLog)
        os_signpost(.begin, log: ollamaLog, name: "Ollama Generate", signpostID: id, "model: %{public}s", model)
        return (ollamaLog, id)
    }

    public static func endOllamaGenerate(_ context: (OSLog, OSSignpostID), tokens: Int) {
        os_signpost(.end, log: context.0, name: "Ollama Generate", signpostID: context.1, "tokens: %d", tokens)
    }

    public static func beginOllamaEmbed(model: String, chunks: Int) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: ollamaLog)
        os_signpost(.begin, log: ollamaLog, name: "Ollama Embed", signpostID: id, "model: %{public}s, chunks: %d", model, chunks)
        return (ollamaLog, id)
    }

    public static func endOllamaEmbed(_ context: (OSLog, OSSignpostID)) {
        os_signpost(.end, log: context.0, name: "Ollama Embed", signpostID: context.1)
    }

    // MARK: - MCP Tracing

    public static func beginMCPToolCall(tool: String) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: mcpLog)
        os_signpost(.begin, log: mcpLog, name: "MCP Tool Call", signpostID: id, "tool: %{public}s", tool)
        return (mcpLog, id)
    }

    public static func endMCPToolCall(_ context: (OSLog, OSSignpostID), success: Bool) {
        os_signpost(.end, log: context.0, name: "MCP Tool Call", signpostID: context.1, "success: %d", success ? 1 : 0)
    }

    // MARK: - Startup Tracing

    public static func beginStartup(phase: String) -> (OSLog, OSSignpostID) {
        let id = signpostID(for: startupLog)
        os_signpost(.begin, log: startupLog, name: "App Startup", signpostID: id, "phase: %{public}s", phase)
        return (startupLog, id)
    }

    public static func endStartup(_ context: (OSLog, OSSignpostID)) {
        os_signpost(.end, log: context.0, name: "App Startup", signpostID: context.1)
    }

    // MARK: - Convenience Timer

    /// Measure an async operation and return its result
    public static func measure<T>(
        _ name: String,
        log: OSLog = OSLog(subsystem: "com.brainai.app", category: "Measure"),
        operation: () async throws -> T
    ) async rethrows -> T {
        let id = signpostID(for: log)
        os_signpost(.begin, log: log, name: "Measure", signpostID: id, "%{public}s", name)
        let result = try await operation()
        os_signpost(.end, log: log, name: "Measure", signpostID: id, "%{public}s done", name)
        return result
    }
}

// MARK: - Memory Tracker

/// Lightweight memory usage tracker for diagnostics
public struct MemoryUsage: Sendable {
    public let residentSize: UInt64
    public let virtualSize: UInt64
    public let peakResident: UInt64

    /// Human-readable resident memory
    public var residentMB: Double {
        Double(residentSize) / 1_048_576
    }

    /// Current process memory usage
    public static func current() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }

        if result == KERN_SUCCESS {
            return MemoryUsage(
                residentSize: info.resident_size,
                virtualSize: info.virtual_size,
                peakResident: info.resident_size_max
            )
        }
        return MemoryUsage(residentSize: 0, virtualSize: 0, peakResident: 0)
    }
}
