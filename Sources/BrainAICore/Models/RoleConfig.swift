import Foundation

// MARK: - Provider Endpoint

/// Configuration for connecting to a provider
public enum ProviderEndpoint: Codable, Sendable, Equatable {
    /// Local provider running on this machine
    case local

    /// Remote Ollama instance
    case remoteOllama(url: String)

    /// Cloud-based API
    case cloudAPI(baseURL: String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .local:
            try container.encode("local", forKey: .type)
        case .remoteOllama(let url):
            try container.encode("remote_ollama", forKey: .type)
            try container.encode(url, forKey: .url)
        case .cloudAPI(let baseURL):
            try container.encode("cloud_api", forKey: .type)
            try container.encode(baseURL, forKey: .baseURL)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "local":
            self = .local
        case "remote_ollama":
            let url = try container.decode(String.self, forKey: .url)
            self = .remoteOllama(url: url)
        case "cloud_api":
            let baseURL = try container.decode(String.self, forKey: .baseURL)
            self = .cloudAPI(baseURL: baseURL)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown provider endpoint type: \(type)"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case url
        case baseURL = "base_url"
    }

    public static func == (lhs: ProviderEndpoint, rhs: ProviderEndpoint) -> Bool {
        switch (lhs, rhs) {
        case (.local, .local):
            return true
        case (.remoteOllama(let lhsUrl), .remoteOllama(let rhsUrl)):
            return lhsUrl == rhsUrl
        case (.cloudAPI(let lhsBase), .cloudAPI(let rhsBase)):
            return lhsBase == rhsBase
        default:
            return false
        }
    }
}

// MARK: - Role Configuration

/// Configuration for a provider role (e.g., embedding, generation)
public struct RoleConfig: Codable, Sendable, Equatable {
    /// Provider identifier
    public let providerID: String

    /// Model identifier
    public let modelID: String

    /// Provider endpoint configuration
    public let endpoint: ProviderEndpoint

    public init(
        providerID: String,
        modelID: String,
        endpoint: ProviderEndpoint
    ) {
        self.providerID = providerID
        self.modelID = modelID
        self.endpoint = endpoint
    }

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case modelID = "model_id"
        case endpoint
    }

    public static func == (lhs: RoleConfig, rhs: RoleConfig) -> Bool {
        lhs.providerID == rhs.providerID &&
            lhs.modelID == rhs.modelID &&
            lhs.endpoint == rhs.endpoint
    }
}
