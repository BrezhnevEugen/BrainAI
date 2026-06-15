import BrainAICore
import Foundation

// BrainAIMCP — standalone Model Context Protocol server over stdio.
//
// External agents (Cursor, Claude Desktop, Claude Code) spawn this binary and
// exchange newline-delimited JSON-RPC over stdin/stdout. It exposes the BrainAI
// knowledge base (LightRAG) and the per-workspace Markdown memory wiki as MCP
// tools. Diagnostics go to stderr so stdout stays a clean JSON-RPC channel.

func log(_ message: String) {
    FileHandle.standardError.write(Data("[BrainAIMCP] \(message)\n".utf8))
}

// Ensure workspaces are loaded from disk before serving so workspace-scoped
// memory tools resolve the active/named workspace correctly.
await WorkspaceManager.shared.reload()

let lightRAGHost = ProcessInfo.processInfo.environment["BRAINAI_LIGHTRAG_HOST"] ?? "localhost"
let lightRAGPort = ProcessInfo.processInfo.environment["BRAINAI_LIGHTRAG_PORT"]
    .flatMap { UInt16($0) } ?? 9621

let client = LocalLightRAGClient(host: lightRAGHost, port: lightRAGPort)
let server = MCPServer(lightRAGClient: client, workspaceManager: .shared)
let transport = StdioServerTransport()

log("starting (lightrag \(lightRAGHost):\(lightRAGPort), \(WorkspaceManager.shared.workspaces.count) workspace(s))")

do {
    try await server.start(transport: transport)
    log("stopped (peer closed stdin)")
} catch let error as MCPServerTransportError {
    log("transport ended: \(error.localizedDescription)")
} catch {
    log("terminated with error: \(error.localizedDescription)")
    exit(1)
}
