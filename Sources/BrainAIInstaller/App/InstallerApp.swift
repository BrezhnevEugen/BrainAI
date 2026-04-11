import SwiftUI
import BrainAICore

// MARK: - Installer Step

enum InstallerStep: Int, CaseIterable, Identifiable {
    case welcome
    case components
    case provider
    case models
    case download
    case complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .components: "Components"
        case .provider: "Provider"
        case .models: "Models"
        case .download: "Install"
        case .complete: "Complete"
        }
    }
}

// MARK: - Installer View Model

@Observable
final class InstallerViewModel: @unchecked Sendable {

    var currentStep: InstallerStep = .welcome
    var selectedLanguage = "en"

    // Components
    var installLightRAG = true
    var installOllama = true
    var installSampleData = false

    // Provider
    var selectedProvider: ProviderChoice = .ollama
    var openAIKey = ""
    var anthropicKey = ""

    // Models
    var selectedLLMModel = "qwen2.5:7b"
    var installEmbeddingModel = true
    var systemRAM: UInt64 = 0

    // Download state
    var downloadTasks: [DownloadTask] = []
    var isDownloading = false
    var currentTaskIndex = 0

    // Complete
    var allComponentsHealthy = false
    var launchAtLogin = true

    // Detected components
    var ollamaInstalled = false
    var pythonInstalled = false
    var homebrewInstalled = false

    private let lock = NSLock()

    init() {
        detectSystemInfo()
    }

    // MARK: - System Detection

    func detectSystemInfo() {
        systemRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024) // GB

        // Detect installed components
        Task {
            let ollamaFound = await checkCommandExists("ollama")
            let pythonFound = await checkCommandExists("python3")
            let brewFound = await checkCommandExists("brew")

            lock.lock()
            ollamaInstalled = ollamaFound
            pythonInstalled = pythonFound
            homebrewInstalled = brewFound
            lock.unlock()
        }
    }

    var recommendedModel: String {
        if systemRAM >= 32 { return "qwen2.5:32b" }
        if systemRAM >= 16 { return "qwen2.5:14b" }
        return "qwen2.5:7b"
    }

    var estimatedDiskSpace: String {
        var totalMB: Int = 0
        totalMB += 50 // BrainAI Core
        if installLightRAG { totalMB += 200 }
        if installOllama { totalMB += 150 }
        if selectedProvider == .ollama {
            if selectedLLMModel.contains("32b") { totalMB += 20_000 }
            else if selectedLLMModel.contains("14b") { totalMB += 9_000 }
            else { totalMB += 4_500 }
            if installEmbeddingModel { totalMB += 300 }
        }
        if installSampleData { totalMB += 10 }

        if totalMB >= 1024 {
            return String(format: "%.1f GB", Double(totalMB) / 1024.0)
        }
        return "\(totalMB) MB"
    }

    // MARK: - Navigation

    func canAdvance() -> Bool {
        switch currentStep {
        case .welcome: return true
        case .components: return true
        case .provider:
            switch selectedProvider {
            case .ollama, .skip: return true
            case .openai: return !openAIKey.isEmpty
            case .anthropic: return !anthropicKey.isEmpty
            }
        case .models: return true
        case .download: return !isDownloading
        case .complete: return false
        }
    }

    func advance() {
        guard let nextIndex = InstallerStep.allCases.firstIndex(of: currentStep)
                .map({ InstallerStep.allCases.index(after: $0) }),
              nextIndex < InstallerStep.allCases.endIndex else { return }

        let next = InstallerStep.allCases[nextIndex]

        // Skip models step if not using Ollama
        if next == .models && selectedProvider != .ollama {
            currentStep = .download
            return
        }

        currentStep = next

        // Auto-start download when reaching download step
        if currentStep == .download {
            Task { await startInstallation() }
        }
    }

    func goBack() {
        guard let prevIndex = InstallerStep.allCases.firstIndex(of: currentStep)
                .map({ InstallerStep.allCases.index(before: $0) }),
              prevIndex >= InstallerStep.allCases.startIndex else { return }

        let prev = InstallerStep.allCases[prevIndex]

        if prev == .models && selectedProvider != .ollama {
            currentStep = .provider
            return
        }

        currentStep = prev
    }

    // MARK: - Installation

    func startInstallation() async {
        lock.lock()
        isDownloading = true
        downloadTasks = buildDownloadTasks()
        currentTaskIndex = 0
        lock.unlock()

        for i in 0..<downloadTasks.count {
            lock.lock()
            currentTaskIndex = i
            downloadTasks[i].status = .inProgress
            lock.unlock()

            do {
                try await executeTask(downloadTasks[i])
                lock.lock()
                downloadTasks[i].status = .completed
                lock.unlock()
            } catch {
                lock.lock()
                downloadTasks[i].status = .failed(error.localizedDescription)
                lock.unlock()
            }
        }

        lock.lock()
        isDownloading = false
        lock.unlock()

        // Move to complete step
        lock.lock()
        currentStep = .complete
        lock.unlock()

        await runHealthChecks()
    }

    private func buildDownloadTasks() -> [DownloadTask] {
        var tasks: [DownloadTask] = []

        if installLightRAG && !pythonInstalled {
            tasks.append(DownloadTask(
                name: "Python Environment",
                description: "Checking Python 3 availability",
                icon: "terminal"
            ))
        }

        if installLightRAG {
            tasks.append(DownloadTask(
                name: "LightRAG Server",
                description: "Installing LightRAG and dependencies",
                icon: "server.rack"
            ))
        }

        if installOllama && !ollamaInstalled {
            tasks.append(DownloadTask(
                name: "Ollama",
                description: "Installing Ollama runtime",
                icon: "cpu"
            ))
        }

        if selectedProvider == .ollama {
            tasks.append(DownloadTask(
                name: "LLM Model (\(selectedLLMModel))",
                description: "Downloading language model",
                icon: "brain"
            ))

            if installEmbeddingModel {
                tasks.append(DownloadTask(
                    name: "Embedding Model",
                    description: "Downloading nomic-embed-text",
                    icon: "square.grid.3x3"
                ))
            }
        }

        if installSampleData {
            tasks.append(DownloadTask(
                name: "Sample Knowledge Base",
                description: "Loading demo data",
                icon: "book"
            ))
        }

        return tasks
    }

    private func executeTask(_ task: DownloadTask) async throws {
        // Simulate installation with delays (real implementation would use Process)
        switch task.name {
        case let name where name.contains("Python"):
            try await runProcess("python3", arguments: ["--version"])
        case let name where name.contains("LightRAG"):
            try await runProcess("pip3", arguments: ["install", "--user", "lightrag-hku"])
        case let name where name.contains("Ollama") && !name.contains("Model"):
            if homebrewInstalled {
                try await runProcess("brew", arguments: ["install", "ollama"])
            } else {
                throw InstallerError.componentNotAvailable("Homebrew not found. Please install Ollama manually from ollama.com")
            }
        case let name where name.contains("LLM Model"):
            try await runProcess("ollama", arguments: ["pull", selectedLLMModel])
        case let name where name.contains("Embedding"):
            try await runProcess("ollama", arguments: ["pull", "nomic-embed-text"])
        case let name where name.contains("Sample"):
            // Copy sample data
            try await Task.sleep(for: .seconds(1))
        default:
            break
        }
    }

    private func runHealthChecks() async {
        do {
            let client = LocalLightRAGClient()
            let health = try await client.healthCheck()
            lock.lock()
            allComponentsHealthy = health.status == "ok" || health.status == "healthy"
            lock.unlock()
        } catch {
            lock.lock()
            allComponentsHealthy = false
            lock.unlock()
        }
    }

    // MARK: - Helpers

    private func checkCommandExists(_ command: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runProcess(_ command: String, arguments: [String]) async throws {
        let process = Process()
        let pipe = Pipe()

        // Find the command path
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [command]
        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe

        try whichProcess.run()
        whichProcess.waitUntilExit()

        let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
        let commandPath = String(data: whichData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/local/bin/\(command)"

        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw InstallerError.processError("\(command) failed: \(output)")
        }
    }
}

// MARK: - Supporting Types

enum ProviderChoice: String, CaseIterable, Identifiable {
    case ollama = "Ollama (Local)"
    case openai = "OpenAI API"
    case anthropic = "Anthropic API"
    case skip = "Skip (Configure Later)"

    var id: String { rawValue }
}

struct DownloadTask: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    var status: DownloadTaskStatus = .pending
    var progress: Double = 0
}

enum DownloadTaskStatus {
    case pending
    case inProgress
    case completed
    case failed(String)
}

enum InstallerError: LocalizedError {
    case componentNotAvailable(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .componentNotAvailable(let msg): return msg
        case .processError(let msg): return msg
        }
    }
}

// MARK: - Main App

@main
struct BrainAIInstallerApp: App {
    @State private var viewModel = InstallerViewModel()

    var body: some Scene {
        WindowGroup {
            InstallerContentView(viewModel: viewModel)
                .frame(width: 700, height: 500)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Installer Content View

struct InstallerContentView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)

            Divider()

            // Navigation buttons
            navigationBar
                .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(InstallerStep.allCases) { step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 24, height: 24)

                        if step.rawValue < viewModel.currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(step == viewModel.currentStep ? .white : .secondary)
                        }
                    }

                    if step != InstallerStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < viewModel.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func stepColor(for step: InstallerStep) -> Color {
        if step.rawValue < viewModel.currentStep.rawValue {
            return Color.accentColor
        } else if step == viewModel.currentStep {
            return Color.accentColor
        } else {
            return Color.secondary.opacity(0.3)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeStepView(viewModel: viewModel)
        case .components:
            ComponentsStepView(viewModel: viewModel)
        case .provider:
            ProviderStepView(viewModel: viewModel)
        case .models:
            ModelsStepView(viewModel: viewModel)
        case .download:
            DownloadStepView(viewModel: viewModel)
        case .complete:
            CompleteStepView(viewModel: viewModel)
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if viewModel.currentStep != .welcome && viewModel.currentStep != .complete {
                Button("Back") {
                    viewModel.goBack()
                }
            }

            Spacer()

            if viewModel.currentStep == .complete {
                Button("Open BrainAI") {
                    NSWorkspace.shared.open(URL(string: "brainai://open")!)
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.currentStep != .download || !viewModel.isDownloading {
                Button(viewModel.currentStep == .download ? "Done" : "Continue") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAdvance())
            }
        }
    }
}
