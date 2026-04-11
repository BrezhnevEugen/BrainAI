import Foundation
import KeychainAccess

// MARK: - KeychainManager

/// Manages secure credential storage using Keychain
public final class KeychainManager: @unchecked Sendable {
    /// Shared instance
    public static let shared = KeychainManager()

    private let keychain: Keychain
    private let lock = NSLock()

    private let apiKeyPrefix = "api_key_"
    private let tokenPrefix = "remote_token_"

    /// Initialize keychain manager
    private init() {
        self.keychain = Keychain(service: "com.brainai.app")
    }

    /// Save API key for a provider
    /// - Parameters:
    ///   - key: The API key value
    ///   - provider: The provider type
    /// - Throws: BrainAIError if save fails
    public func saveAPIKey(_ key: String, for provider: ProviderType) throws {
        lock.lock()
        defer { lock.unlock() }

        let identifier = apiKeyPrefix + provider.rawValue

        do {
            try keychain.set(key, key: identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to save API key: \(error.localizedDescription)")
        }
    }

    /// Load API key for a provider
    /// - Parameter provider: The provider type
    /// - Returns: The API key or nil if not found
    /// - Throws: BrainAIError if load fails
    public func loadAPIKey(for provider: ProviderType) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        let identifier = apiKeyPrefix + provider.rawValue

        do {
            return try keychain.get(identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to load API key: \(error.localizedDescription)")
        }
    }

    /// Delete API key for a provider
    /// - Parameter provider: The provider type
    /// - Throws: BrainAIError if delete fails
    public func deleteAPIKey(for provider: ProviderType) throws {
        lock.lock()
        defer { lock.unlock() }

        let identifier = apiKeyPrefix + provider.rawValue

        do {
            try keychain.remove(identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to delete API key: \(error.localizedDescription)")
        }
    }

    /// Save authentication token for a remote workspace
    /// - Parameters:
    ///   - token: The authentication token
    ///   - workspaceID: The workspace identifier
    /// - Throws: BrainAIError if save fails
    public func saveRemoteToken(_ token: String, for workspaceID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let identifier = tokenPrefix + workspaceID.uuidString

        do {
            try keychain.set(token, key: identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to save remote token: \(error.localizedDescription)")
        }
    }

    /// Load authentication token for a remote workspace
    /// - Parameter workspaceID: The workspace identifier
    /// - Returns: The authentication token or nil if not found
    /// - Throws: BrainAIError if load fails
    public func loadRemoteToken(for workspaceID: UUID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        let identifier = tokenPrefix + workspaceID.uuidString

        do {
            return try keychain.get(identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to load remote token: \(error.localizedDescription)")
        }
    }

    /// Delete authentication token for a remote workspace
    /// - Parameter workspaceID: The workspace identifier
    /// - Throws: BrainAIError if delete fails
    public func deleteRemoteToken(for workspaceID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let identifier = tokenPrefix + workspaceID.uuidString

        do {
            try keychain.remove(identifier)
        } catch {
            throw BrainAIError.keychainError("Failed to delete remote token: \(error.localizedDescription)")
        }
    }
}
