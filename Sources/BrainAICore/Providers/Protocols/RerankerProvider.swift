import Foundation

// MARK: - RerankerProvider Protocol

/// Protocol for document reranking providers
public protocol RerankerProvider: Sendable {
    /// Unique identifier for the provider
    var id: String { get }

    /// Human-readable display name
    var displayName: String { get }

    /// Whether the provider is currently available
    var isAvailable: Bool { get async }

    /// Rerank documents based on relevance to a query
    /// - Parameters:
    ///   - query: The search query
    ///   - documents: Array of document texts to rerank
    ///   - topK: Maximum number of top results to return
    /// - Returns: Array of ranked documents sorted by relevance
    func rerank(query: String, documents: [String], topK: Int) async throws -> [RankedDocument]
}
