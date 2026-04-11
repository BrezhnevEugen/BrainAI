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
        case .welcome: InstallerL10n.Step.welcome
        case .components: InstallerL10n.Step.components
        case .provider: InstallerL10n.Step.provider
        case .models: InstallerL10n.Step.models
        case .download: InstallerL10n.Step.install
        case .complete: InstallerL10n.Step.complete
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

    /// Canonical Ollama names from `ollama list` (see `OllamaModelInventory`).
    private var installedOllamaModelCanonicalNames = Set<String>()
    var isScanningOllamaModels = false

    /// Scans `ollama list` (JSON or text) on a background thread; updates `installedOllamaModelCanonicalNames`.
    func scanInstalledOllamaModels() async {
        await MainActor.run { isScanningOllamaModels = true }
        let names = await OllamaModelInventory.fetchInstalledCanonicalNames()
        await MainActor.run {
            lock.lock()
            installedOllamaModelCanonicalNames = names
            lock.unlock()
            isScanningOllamaModels = false
        }
    }

    func isOllamaModelInstalled(_ modelId: String) -> Bool {
        let canonical = OllamaModelInventory.canonicalName(modelId)
        lock.lock()
        defer { lock.unlock() }
        return installedOllamaModelCanonicalNames.contains(canonical)
    }

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
            applyDetectedComponents(ollama: ollamaFound, python: pythonFound, brew: brewFound)
        }
    }

    var recommendedModel: String {
        if systemRAM >= 32 { return "qwen2.5:32b" }
        if systemRAM >= 16 { return "qwen2.5:14b" }
        return "qwen2.5:7b"
    }

    /// Rough size for **third‑party** pieces this wizard installs (pip, brew, `ollama pull`).
    /// The BrainAI `.app` bundle is not downloaded by these steps — it comes from the disk image.
    var estimatedDiskSpace: String {
        var totalMB: Int = 0
        if installLightRAG { totalMB += 200 }
        if installOllama { totalMB += 150 }
        if selectedProvider == .ollama {
            if !isOllamaModelInstalled(selectedLLMModel) {
                if selectedLLMModel.contains("32b") { totalMB += 20_000 }
                else if selectedLLMModel.contains("14b") { totalMB += 9_000 }
                else { totalMB += 4_500 }
            }
            if installEmbeddingModel, !isOllamaModelInstalled("nomic-embed-text") {
                totalMB += 300
            }
        }
        if installSampleData { totalMB += 10 }

        if totalMB >= 1024 {
            return InstallerL10n.DiskSpace.gigabytes(Double(totalMB) / 1024.0)
        }
        return InstallerL10n.DiskSpace.megabytes(totalMB)
    }

    /// Same logic as the install step task list, for UI preview on the Models screen.
    var plannedInstallStepSummaries: [PlannedInstallStepSummary] {
        lock.lock()
        let snap = installedOllamaModelCanonicalNames
        lock.unlock()
        return buildDownloadTasks(installedOllama: snap).enumerated().map { index, task in
            PlannedInstallStepSummary(
                id: "\(index)-\(task.name)",
                title: task.name,
                subtitle: task.description
            )
        }
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
        beginInstallation()

        for i in 0..<downloadTasks.count {
            markTaskInProgress(i)

            do {
                try await executeTask(downloadTasks[i])
                markTaskCompleted(i)
            } catch {
                markTaskFailed(i, message: error.localizedDescription)
            }
        }

        finishInstallation()
        await runHealthChecks()
    }

    private func buildDownloadTasks(installedOllama: Set<String>) -> [DownloadTask] {
        func ollamaHas(_ modelId: String) -> Bool {
            installedOllama.contains(OllamaModelInventory.canonicalName(modelId))
        }

        var tasks: [DownloadTask] = []

        if installLightRAG && !pythonInstalled {
            tasks.append(DownloadTask(
                kind: .pythonEnvironment,
                name: InstallerL10n.Task.pythonName,
                description: InstallerL10n.Task.pythonDesc,
                icon: "terminal"
            ))
        }

        if installLightRAG {
            tasks.append(DownloadTask(
                kind: .lightragServer,
                name: InstallerL10n.Task.lightragName,
                description: InstallerL10n.Task.lightragDesc,
                icon: "server.rack"
            ))
        }

        if installOllama && !ollamaInstalled {
            tasks.append(DownloadTask(
                kind: .ollamaRuntime,
                name: InstallerL10n.Task.ollamaName,
                description: InstallerL10n.Task.ollamaDesc,
                icon: "cpu"
            ))
        }

        if selectedProvider == .ollama {
            if !ollamaHas(selectedLLMModel) {
                tasks.append(DownloadTask(
                    kind: .llmModel,
                    name: InstallerL10n.Task.llmName(model: selectedLLMModel),
                    description: InstallerL10n.Task.llmDesc,
                    icon: "brain"
                ))
            }

            if installEmbeddingModel, !ollamaHas("nomic-embed-text") {
                tasks.append(DownloadTask(
                    kind: .embeddingModel,
                    name: InstallerL10n.Task.embedName,
                    description: InstallerL10n.Task.embedDesc,
                    icon: "square.grid.3x3"
                ))
            }
        }

        if installSampleData {
            tasks.append(DownloadTask(
                kind: .sampleKnowledgeBase,
                name: InstallerL10n.Task.sampleName,
                description: InstallerL10n.Task.sampleDesc,
                icon: "book"
            ))
        }

        return tasks
    }

    private func executeTask(_ task: DownloadTask) async throws {
        switch task.kind {
        case .pythonEnvironment:
            try await runProcess("python3", arguments: ["--version"])
        case .lightragServer:
            try await runProcess("pip3", arguments: ["install", "--user", "lightrag-hku"])
        case .ollamaRuntime:
            if homebrewInstalled {
                try await runProcess("brew", arguments: ["install", "ollama"])
            } else {
                throw InstallerError.componentNotAvailable(InstallerL10n.ErrorMessage.homebrewOllama)
            }
        case .llmModel:
            try await runProcess("ollama", arguments: ["pull", selectedLLMModel])
        case .embeddingModel:
            try await runProcess("ollama", arguments: ["pull", "nomic-embed-text"])
        case .sampleKnowledgeBase:
            try await Task.sleep(for: .seconds(1))
        }
    }

    private func runHealthChecks() async {
        do {
            let client = LocalLightRAGClient()
            let health = try await client.healthCheck()
            setHealthy(health.status == "ok" || health.status == "healthy")
        } catch {
            setHealthy(false)
        }
    }

    // MARK: - Sync Helpers (avoid NSLock in async context)

    private func applyDetectedComponents(ollama: Bool, python: Bool, brew: Bool) {
        lock.lock()
        ollamaInstalled = ollama
        pythonInstalled = python
        homebrewInstalled = brew
        lock.unlock()
    }

    private func beginInstallation() {
        lock.lock()
        let installedSnap = installedOllamaModelCanonicalNames
        isDownloading = true
        downloadTasks = buildDownloadTasks(installedOllama: installedSnap)
        currentTaskIndex = 0
        lock.unlock()
    }

    private func markTaskInProgress(_ index: Int) {
        lock.lock()
        currentTaskIndex = index
        downloadTasks[index].status = .inProgress
        lock.unlock()
    }

    private func markTaskCompleted(_ index: Int) {
        lock.lock()
        downloadTasks[index].status = .completed
        lock.unlock()
    }

    private func markTaskFailed(_ index: Int, message: String) {
        lock.lock()
        downloadTasks[index].status = .failed(message)
        lock.unlock()
    }

    private func finishInstallation() {
        lock.lock()
        isDownloading = false
        currentStep = .complete
        lock.unlock()
    }

    private func setHealthy(_ value: Bool) {
        lock.lock()
        allComponentsHealthy = value
        lock.unlock()
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
    case ollama
    case openai
    case anthropic
    case skip

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .ollama: InstallerL10n.Provider.choiceOllama
        case .openai: InstallerL10n.Provider.choiceOpenAI
        case .anthropic: InstallerL10n.Provider.choiceAnthropic
        case .skip: InstallerL10n.Provider.choiceSkip
        }
    }
}

/// One row in the “what will run” preview (Models step).
struct PlannedInstallStepSummary: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
}

enum InstallTaskKind: Equatable, Sendable {
    case pythonEnvironment
    case lightragServer
    case ollamaRuntime
    case llmModel
    case embeddingModel
    case sampleKnowledgeBase
}

struct DownloadTask: Identifiable {
    let id = UUID()
    let kind: InstallTaskKind
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
                .frame(minWidth: 700, minHeight: 560)
                .frame(idealWidth: 720, idealHeight: 620)
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

            // Scroll so tall steps (e.g. Welcome) never push Continue/Back below the window.
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation buttons (always visible above scroll area)
            navigationBar
                .padding(16)
                .layoutPriority(1)
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
                Button(InstallerL10n.Nav.back) {
                    viewModel.goBack()
                }
            }

            Spacer()

            if viewModel.currentStep == .complete {
                Button(InstallerL10n.Nav.openBrainAI) {
                    NSWorkspace.shared.open(URL(string: "brainai://open")!)
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.currentStep != .download || !viewModel.isDownloading {
                Button(viewModel.currentStep == .download ? InstallerL10n.Nav.done : InstallerL10n.Nav.continue) {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAdvance())
            }
        }
    }
}
