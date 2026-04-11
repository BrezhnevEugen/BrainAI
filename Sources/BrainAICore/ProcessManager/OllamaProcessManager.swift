import Foundation

// MARK: - OllamaProcessManager

/// Manager for the Ollama process lifecycle
public actor OllamaProcessManager: ManagedProcess {
    public let processName: String = "ollama"
    public let port: UInt16

    private var process: Process?
    private var processStatus: ProcessStatus = .stopped
    private let baseURL: URL

    /// Initialize Ollama process manager
    /// - Parameter port: Port Ollama listens on (default 11434)
    /// - Parameter baseURL: Base URL for API calls (default http://localhost:port)
    public init(port: UInt16 = 11434, baseURL: URL? = nil) {
        self.port = port
        if let baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = URL(string: "http://localhost:\(port)")!
        }
    }

    public var status: ProcessStatus {
        get async {
            processStatus
        }
    }

    public func start() async throws {
        // Check if already running
        if await status == .running {
            return
        }

        processStatus = .starting

        defer {
            if processStatus == .starting {
                processStatus = .error("Failed to start")
            }
        }

        // Try standard Ollama installation paths
        let ollamaPaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".ollama/bin/ollama").path,
        ]

        var process: Process?
        var executablePath: String?

        for path in ollamaPaths {
            if FileManager.default.fileExists(atPath: path) {
                executablePath = path
                break
            }
        }

        guard let executablePath else {
            throw BrainAIError.processError("Ollama executable not found")
        }

        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: executablePath)
        newProcess.arguments = ["serve"]

        // Set environment
        var env = ProcessInfo.processInfo.environment
        env["OLLAMA_HOST"] = "127.0.0.1:\(port)"
        newProcess.environment = env

        do {
            try newProcess.run()
            self.process = newProcess
            processStatus = .running

            // Wait for health check
            try await waitForHealthy(maxRetries: 30, delay: 1.0)
        } catch {
            processStatus = .error(error.localizedDescription)
            throw BrainAIError.processError("Failed to start Ollama: \(error.localizedDescription)")
        }
    }

    public func stop() async throws {
        guard let process = self.process, process.isRunning else {
            processStatus = .stopped
            return
        }

        processStatus = .starting

        defer {
            if processStatus == .starting {
                processStatus = .stopped
            }
        }

        process.terminate()

        // Wait for process to terminate
        let deadline = Date().addingTimeInterval(5.0)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.interrupt()
        }

        self.process = nil
        processStatus = .stopped
    }

    public func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }

    private func waitForHealthy(maxRetries: Int, delay: TimeInterval) async throws {
        for _ in 0..<maxRetries {
            do {
                if try await healthCheck() {
                    return
                }
            } catch {
                // Health check failed, continue retrying
            }

            try await Task.sleep(for: .seconds(delay))
        }

        throw BrainAIError.processError("Ollama did not become healthy")
    }
}
