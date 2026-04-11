import Foundation

/// XPC protocol for inter-process communication between BrainAI apps
@objc public protocol BrainAIXPCProtocol {

    // MARK: - Service Status

    /// Get the current status of Ollama service
    func getOllamaStatus(withReply reply: @escaping (String) -> Void)

    /// Get the current status of LightRAG service
    func getLightRAGStatus(withReply reply: @escaping (String) -> Void)

    // MARK: - Service Control

    /// Start all services
    func startAllServices(withReply reply: @escaping (Bool, String?) -> Void)

    /// Stop all services
    func stopAllServices(withReply reply: @escaping (Bool, String?) -> Void)

    /// Start a specific workspace's LightRAG instance
    func startWorkspace(_ workspaceID: String, withReply reply: @escaping (Bool, String?) -> Void)

    /// Stop a specific workspace's LightRAG instance
    func stopWorkspace(_ workspaceID: String, withReply reply: @escaping (Bool, String?) -> Void)

    // MARK: - Knowledge Base

    /// Query the knowledge base
    func query(_ question: String, mode: String, topK: Int, withReply reply: @escaping (String?, String?) -> Void)

    /// Insert text into the knowledge base
    func insertText(_ text: String, description: String, withReply reply: @escaping (Bool, String?) -> Void)

    // MARK: - Configuration

    /// Notify other processes that configuration changed
    func notifyConfigurationChanged(withReply reply: @escaping () -> Void)

    /// Get current overall service status as JSON string
    func getServiceInfo(withReply reply: @escaping (String) -> Void)
}
