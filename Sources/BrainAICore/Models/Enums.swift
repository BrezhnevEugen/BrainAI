import Foundation

// MARK: - Provider Types

/// Represents different LLM provider types
public enum ProviderType: String, Codable, Sendable, Hashable, CaseIterable {
    case ollama
    case openai
    case anthropic
    case deepseek
    case jina
    case cohere
}

// MARK: - Search Modes

/// Different search modes for querying the knowledge graph
public enum SearchMode: String, Codable, Sendable, Hashable, CaseIterable {
    /// Entity-focused local search
    case local
    /// Broad global summaries
    case global
    /// Combined local and global search
    case hybrid
    /// Vector search only
    case naive
    /// Graph and vector combined search
    case mix
}

// MARK: - Document Status

/// Status of a document in the knowledge base
public enum DocumentStatus: String, Codable, Sendable, Hashable {
    case pending
    case processing
    case processed
    case failed
}

// MARK: - Process Status

/// Status of a long-running process
public enum ProcessStatus: Codable, Sendable, Hashable {
    case stopped
    case starting
    case running
    case error(String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .stopped:
            try container.encode("stopped")
        case .starting:
            try container.encode("starting")
        case .running:
            try container.encode("running")
        case .error(let message):
            try container.encode(["error": message])
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let status = try? container.decode(String.self) {
            switch status {
            case "stopped":
                self = .stopped
            case "starting":
                self = .starting
            case "running":
                self = .running
            default:
                self = .error(status)
            }
        } else if let dict = try? container.decode([String: String].self),
                  let errorMsg = dict["error"] {
            self = .error(errorMsg)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ProcessStatus")
        }
    }
}

// MARK: - Connection Mode

/// Connection mode for providers
public enum ConnectionMode: String, Codable, Sendable, Hashable {
    case local
    case remote
}

// MARK: - Message Role

/// Role of a message in conversation
public enum MessageRole: String, Codable, Sendable, Hashable {
    case user
    case assistant
    case system
}

// MARK: - Model Capability

/// Capabilities that a model can have
public enum ModelCapability: String, Codable, Sendable, Hashable, CaseIterable {
    case chat
    case embedding
    case extraction
    case vision
}

// MARK: - Keep Alive Duration

/// Keep-alive duration for Ollama API
public enum KeepAliveDuration: Codable, Sendable, Hashable {
    case seconds(Int)
    case minutes(Int)
    case forever

    /// Raw value string for Ollama API
    public var rawValue: String {
        switch self {
        case .seconds(let value):
            return "\(value)s"
        case .minutes(let value):
            return "\(value)m"
        case .forever:
            return "-1"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if value == "-1" {
            self = .forever
        } else if value.hasSuffix("s") {
            if let seconds = Int(value.dropLast()) {
                self = .seconds(seconds)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid seconds format")
            }
        } else if value.hasSuffix("m") {
            if let minutes = Int(value.dropLast()) {
                self = .minutes(minutes)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid minutes format")
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid duration format")
        }
    }
}

// MARK: - Workspace Start Policy

/// Policy for starting workspace on app launch
public enum WorkspaceStartPolicy: String, Codable, Sendable, Hashable, CaseIterable {
    /// Always start the workspace
    case always
    /// Start only on demand
    case onDemand
    /// Require manual start
    case manual
}
