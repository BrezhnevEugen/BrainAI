import Foundation

// MARK: - LightRAGProcessManager

/// Manager for LightRAG process lifecycle
public actor LightRAGProcessManager: ManagedProcess {
    public let processName: String = "lightrag"
    public let port: UInt16

    private var process: Process?
    private var processStatus: ProcessStatus = .stopped
    private let workingDirectory: URL
    private let baseURL: URL
    private var environmentVariables: [String: String]

    /// Initialize LightRAG process manager
    /// - Parameters:
    ///   - workingDirectory: Path to LightRAG installation directory
    ///   - port: Port to run LightRAG on (default 8000)
    ///   - baseURL: Base URL for API calls
    ///   - environmentVariables: Additional environment variables to inject
    public init(
        workingDirectory: URL,
        port: UInt16 = 8000,
        baseURL: URL? = nil,
        environmentVariables: [String: String] = [:]
    ) {
        self.workingDirectory = workingDirectory
        self.port = port
        if let baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = URL(string: "http://localhost:\(port)")!
        }
        self.environmentVariables = environmentVariables
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

        let newProcess = Process()

        // Try to use uv first, fallback to python
        let shellPaths = ["/bin/bash", "/bin/sh"]
        var shellPath: String?

        for path in shellPaths {
            if FileManager.default.fileExists(atPath: path) {
                shellPath = path
                break
            }
        }

        guard let shellPath else {
            throw BrainAIError.processError("Shell not found")
        }

        newProcess.executableURL = URL(fileURLWithPath: shellPath)

        let command = "uv run --extra api lightrag-server 2>&1 || python -m lightrag.server"
        newProcess.arguments = ["-c", command]

        newProcess.currentDirectoryURL = workingDirectory

        // Set environment
        var env = ProcessInfo.processInfo.environment
        env["LIGHTRAG_PORT"] = "\(port)"
        env["PYTHONUNBUFFERED"] = "1"

        // Presets from app language + provider settings (SUMMARY_LANGUAGE, chunking, Ollama hosts, etc.)
        for (key, value) in AppConfiguration.shared.lightRAGServerEnvironment(port: port) {
            env[key] = value
        }

        // Merge custom environment variables (caller wins)
        for (key, value) in environmentVariables {
            env[key] = value
        }

        newProcess.environment = env

        do {
            try newProcess.run()
            self.process = newProcess
            processStatus = .running

            // Wait for health check
            try await waitForHealthy(maxRetries: 30, delay: 1.0)
        } catch {
            processStatus = .error(error.localizedDescription)
            throw BrainAIError.processError("Failed to start LightRAG: \(error.localizedDescription)")
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
        let url = baseURL.appendingPathComponent("health")

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }

    /// Set or update environment variables for the process
    /// - Parameter variables: Dictionary of environment variables
    public func setEnvironmentVariables(_ variables: [String: String]) {
        self.environmentVariables = variables
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

        throw BrainAIError.processError("LightRAG did not become healthy")
    }
}
