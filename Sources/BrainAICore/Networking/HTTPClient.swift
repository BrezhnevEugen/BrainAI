import Foundation
import CommonCrypto

// MARK: - HTTP Client Error

/// Errors that can occur during HTTP requests
public enum HTTPClientError: LocalizedError {
    /// Invalid URL format
    case invalidURL
    /// Request failed with status code and optional response data
    case requestFailed(statusCode: Int, data: Data?)
    /// Failed to decode response
    case decodingFailed(String)
    /// Network-related error
    case networkError(String)
    /// Authentication failed (401)
    case unauthorized
    /// TLS certificate pinning failed
    case tlsPinningFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format"
        case .requestFailed(let statusCode, _):
            return "HTTP request failed with status code: \(statusCode)"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Authentication failed (401 Unauthorized)"
        case .tlsPinningFailed:
            return "TLS certificate pinning verification failed"
        }
    }
}

// MARK: - TLS Pinning Delegate

/// URLSession delegate for TLS certificate pinning
public final class TLSPinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let pinnedCertificateHashes: Set<String>

    /// Initialize with SHA-256 hashes of pinned certificate public keys
    public init(pinnedCertificateHashes: Set<String>) {
        self.pinnedCertificateHashes = pinnedCertificateHashes
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // If no hashes pinned, accept default trust
        guard !pinnedCertificateHashes.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate server trust
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(serverTrust, &error)

        guard trusted else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check pinned certificates
        if let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
            for certificate in certificateChain {
                let certData = SecCertificateCopyData(certificate) as Data
                let hash = certData.sha256HexString
                if pinnedCertificateHashes.contains(hash) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
            }
        }

        // No matching pin found
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

// MARK: - Data SHA-256 Helper

private extension Data {
    var sha256HexString: String {
        var hash = [UInt8](repeating: 0, count: 32)
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - HTTP Client

/// Generic HTTP client for making REST API requests with JSON support
public actor HTTPClient {
    private let baseURL: String
    private let authToken: String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let timeout: TimeInterval
    private let session: URLSession

    /// Initializes the HTTP client
    /// - Parameters:
    ///   - baseURL: Base URL for all requests
    ///   - authToken: Optional Bearer token for authentication
    ///   - timeout: Request timeout in seconds (default: 30)
    ///   - pinnedCertificateHashes: Optional TLS certificate pin hashes (SHA-256)
    public init(
        baseURL: String,
        authToken: String? = nil,
        timeout: TimeInterval = 30,
        pinnedCertificateHashes: Set<String>? = nil
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.timeout = timeout

        // Configure URLSession with optional TLS pinning
        if let hashes = pinnedCertificateHashes, !hashes.isEmpty {
            let delegate = TLSPinningDelegate(pinnedCertificateHashes: hashes)
            self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        } else {
            self.session = URLSession.shared
        }

        // Configure decoder for snake_case
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        // Configure encoder for snake_case
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    /// Performs a GET request
    /// - Parameters:
    ///   - path: Endpoint path (relative to baseURL)
    ///   - queryParameters: Optional query parameters to append to URL
    /// - Returns: Decoded response of type T
    public func get<T: Decodable>(_ path: String, queryParameters: [String: String]? = nil) async throws -> T {
        var urlString = baseURL + path
        if let queryParameters = queryParameters {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        addAuthHeader(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw error
        } catch let error as DecodingError {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        } catch {
            throw HTTPClientError.networkError(error.localizedDescription)
        }
    }

    /// Performs a POST request with JSON body
    /// - Parameters:
    ///   - path: Endpoint path (relative to baseURL)
    ///   - body: Request body to be JSON encoded
    /// - Returns: Decoded response of type T
    public func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            request.httpBody = try encoder.encode(body)
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw error
        } catch let error as DecodingError {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        } catch {
            throw HTTPClientError.networkError(error.localizedDescription)
        }
    }

    /// Performs a DELETE request
    /// - Parameters:
    ///   - path: Endpoint path (relative to baseURL)
    ///   - queryParameters: Optional query parameters
    /// - Returns: Decoded response of type T
    public func delete<T: Decodable>(_ path: String, queryParameters: [String: String]? = nil) async throws -> T {
        var urlString = baseURL + path
        if let queryParameters = queryParameters {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        addAuthHeader(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw error
        } catch let error as DecodingError {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        } catch {
            throw HTTPClientError.networkError(error.localizedDescription)
        }
    }

    /// Performs a PATCH request with JSON body
    /// - Parameters:
    ///   - path: Endpoint path (relative to baseURL)
    ///   - body: Request body to be JSON encoded
    /// - Returns: Decoded response of type T
    public func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            request.httpBody = try encoder.encode(body)
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            return try decoder.decode(T.self, from: data)
        } catch let error as HTTPClientError {
            throw error
        } catch let error as DecodingError {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        } catch {
            throw HTTPClientError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func addAuthHeader(to request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.networkError(URLError(.badServerResponse).localizedDescription)
        }

        if httpResponse.statusCode == 401 {
            throw HTTPClientError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPClientError.requestFailed(statusCode: httpResponse.statusCode, data: nil)
        }
    }
}
