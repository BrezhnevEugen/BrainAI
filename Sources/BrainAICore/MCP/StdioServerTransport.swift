import Foundation

// MARK: - MCP Server Transport Error

/// Errors for server-side MCP transports.
public enum MCPServerTransportError: LocalizedError {
    case closed
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .closed: "MCP transport closed (EOF)"
        case .writeFailed(let message): "MCP transport write failed: \(message)"
        }
    }
}

// MARK: - Stdio Server Transport

/// Server-side MCP transport over this process's stdin/stdout.
///
/// External agents (Cursor, Claude Desktop, Claude Code) spawn the BrainAI MCP
/// binary and speak newline-delimited JSON-RPC over stdio. Only JSON-RPC may be
/// written to stdout — any diagnostics must go to stderr.
///
/// `receive()` performs a blocking read on `availableData`; this is intentional
/// for a dedicated server process whose sole job is to serve one stdio peer.
public actor StdioServerTransport: MCPTransport {

    private let input: FileHandle
    private let output: FileHandle
    private var buffer = Data()

    public init(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        self.input = input
        self.output = output
    }

    public func send(_ data: Data) async throws {
        // JSON-RPC messages are newline-delimited.
        var message = data
        if message.last != UInt8(ascii: "\n") {
            message.append(UInt8(ascii: "\n"))
        }
        do {
            try output.write(contentsOf: message)
        } catch {
            throw MCPServerTransportError.writeFailed(error.localizedDescription)
        }
    }

    public func receive() async throws -> Data {
        while true {
            if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = Data(buffer[buffer.startIndex..<newlineIndex])
                buffer = Data(buffer[(newlineIndex + 1)...])
                if line.isEmpty { continue }
                return line
            }

            let chunk = input.availableData
            if chunk.isEmpty {
                // EOF — the peer closed stdin.
                throw MCPServerTransportError.closed
            }
            buffer.append(chunk)
        }
    }

    public func close() async {
        try? output.synchronize()
    }
}
