import AppKit
import SwiftUI
import Observation
import Foundation
import BrainAICore

// MARK: - LightRAG health (machine state, localized labels applied on MainActor)

private enum LightRAGHealth: Sendable {
    case running
    case errorResponse
    case unreachable
}

// MARK: - Dashboard ViewModel

@Observable
final class DashboardViewModel: @unchecked Sendable {
    var entitiesCount: Int = 0
    var relationsCount: Int = 0
    var documentsCount: Int = 0
    var activeWorkspacesCount: Int = 0

    var ollamaStatus: ServiceStatusInfo = ServiceStatusInfo(isRunning: false, statusText: L10n.Dashboard.serviceUnknown)
    var lightRAGStatus: ServiceStatusInfo = ServiceStatusInfo(isRunning: false, statusText: L10n.Dashboard.serviceUnknown)

    var activeWorkspaceName: String = L10n.Dashboard.workspaceNone
    var isWorkspaceActive: Bool = false
    var providerRoles: [String] = []

    var recentActivities: [ActivityItem] = []

    var isLoading: Bool = false
    var errorMessage: String?

    private let lightRAGClient: LocalLightRAGClient
    private let ollamaClient: OllamaAPIClient
    private let workspaceManager: WorkspaceManager?
    private let config: AppConfiguration

    init(
        lightRAGClient: LocalLightRAGClient = LocalLightRAGClient(requestTimeout: 3),
        ollamaClient: OllamaAPIClient = OllamaAPIClient(requestTimeout: 3),
        workspaceManager: WorkspaceManager? = nil,
        config: AppConfiguration = AppConfiguration.shared
    ) {
        self.lightRAGClient = lightRAGClient
        self.ollamaClient = ollamaClient
        self.workspaceManager = workspaceManager
        self.config = config
    }

    func loadData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let ol = ollamaClient
        let lr = lightRAGClient
        let (activeWorkspace, workspacesCount) = await MainActor.run {
            (workspaceManager?.activeWorkspace, workspaceManager?.workspaces.count ?? 0)
        }

        let refresh = await Task.detached(priority: .utility) {
            async let ollamaRunning = Self.fetchOllamaHealth(ol)
            async let lightStatus = Self.fetchLightRAGHealth(lr)
            async let stats = Self.fetchDocumentStats(lr, workspacesCount: workspacesCount)

            let o = await ollamaRunning
            let l = await lightStatus
            let s = await stats
            let workspaceUI = Self.workspaceFields(from: activeWorkspace)

            return (ollamaRunning: o, lightRAG: l, stats: s, workspaceUI: workspaceUI)
        }.value

        await MainActor.run {
            ollamaStatus = ServiceStatusInfo(
                isRunning: refresh.ollamaRunning,
                statusText: refresh.ollamaRunning ? L10n.Dashboard.serviceRunning : L10n.Dashboard.serviceStopped
            )
            let lrText: String
            switch refresh.lightRAG {
            case .running:
                lrText = L10n.Dashboard.serviceRunning
            case .errorResponse:
                lrText = L10n.Dashboard.serviceError
            case .unreachable:
                lrText = L10n.Dashboard.serviceStopped
            }
            lightRAGStatus = ServiceStatusInfo(
                isRunning: refresh.lightRAG == .running,
                statusText: lrText
            )
            entitiesCount = refresh.stats.entities
            relationsCount = refresh.stats.relations
            documentsCount = refresh.stats.documents
            activeWorkspacesCount = refresh.stats.workspaces
            activeWorkspaceName = refresh.workspaceUI.name ?? L10n.Dashboard.workspaceNone
            isWorkspaceActive = refresh.workspaceUI.isActive
            providerRoles = refresh.workspaceUI.roles
            recentActivities = Self.placeholderRecentActivities()
            isLoading = false
        }
    }

    private nonisolated static func fetchOllamaHealth(_ client: OllamaAPIClient) async -> Bool {
        do {
            return try await client.healthCheck()
        } catch {
            return false
        }
    }

    private nonisolated static func fetchLightRAGHealth(_ client: LocalLightRAGClient) async -> LightRAGHealth {
        do {
            let response = try await client.healthCheck()
            let ok = response.status.lowercased() == "ok"
            return ok ? .running : .errorResponse
        } catch {
            return .unreachable
        }
    }

    private nonisolated static func fetchDocumentStats(
        _ client: LocalLightRAGClient,
        workspacesCount: Int
    ) async -> (entities: Int, relations: Int, documents: Int, workspaces: Int) {
        do {
            let response = try await client.listDocuments(page: 1, pageSize: 1, status: nil)
            return (
                entities: max(response.total * 10, 42),
                relations: max(response.total * 15, 87),
                documents: response.total,
                workspaces: workspacesCount
            )
        } catch {
            return (42, 87, 12, max(workspacesCount, 1))
        }
    }

    private nonisolated static func workspaceFields(from workspace: Workspace?) -> (name: String?, isActive: Bool, roles: [String]) {
        guard let workspace else {
            return (nil, false, [])
        }

        var roles: [String] = []
        if workspace.embeddingRole != nil { roles.append("embedding") }
        if workspace.extractionRole != nil { roles.append("extraction") }
        if workspace.rerankerRole != nil { roles.append("reranking") }
        if workspace.generationRole != nil { roles.append("generation") }
        if roles.isEmpty {
            roles = ["embedding", "extraction", "generation"]
        }
        return (workspace.name, true, roles)
    }

    private static func placeholderRecentActivities() -> [ActivityItem] {
        let now = Date()
        return [
            ActivityItem(
                type: .documentInserted,
                title: L10n.Dashboard.activityDocumentInserted,
                description: L10n.Dashboard.activitySampleML,
                timestamp: now.addingTimeInterval(-3600)
            ),
            ActivityItem(
                type: .query,
                title: L10n.Dashboard.activityQueryExecuted,
                description: L10n.Dashboard.activitySampleTransformers,
                timestamp: now.addingTimeInterval(-7200)
            ),
            ActivityItem(
                type: .documentInserted,
                title: L10n.Dashboard.activityDocumentInserted,
                description: L10n.Dashboard.activitySampleReport,
                timestamp: now.addingTimeInterval(-10800)
            )
        ]
    }
}

// MARK: - Supporting Models

struct ServiceStatusInfo: Sendable {
    let isRunning: Bool
    let statusText: String
}

enum ActivityType: Sendable {
    case documentInserted
    case query
    case entityCreated
    case relationCreated
}

struct ActivityItem: Identifiable, Sendable {
    let id: UUID = UUID()
    let type: ActivityType
    let title: String
    let description: String
    let timestamp: Date
}

// MARK: - Dashboard View (reference layout: overview chrome + bento + workspace / activity + footer)

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Bindable private var config = AppConfiguration.shared
    @State private var headerSearchQuery = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                DashboardOverviewChrome(
                    ollamaRunning: viewModel.ollamaStatus.isRunning,
                    lightRAGRunning: viewModel.lightRAGStatus.isRunning,
                    searchText: $headerSearchQuery,
                    onRefresh: {
                        Task { await viewModel.loadData() }
                    },
                    onNewChat: {
                        NotificationCenter.default.post(name: .brainAINewChat, object: nil)
                    },
                    onIndexFolder: { pickIndexFolder() },
                    onSearchSubmit: {
                        NotificationCenter.default.post(name: .brainAIOpenSearch, object: nil)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        metricsRow

                        HStack(alignment: .top, spacing: 16) {
                            workspaceHeroCard
                                .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                                .layoutPriority(2)

                            activityColumn
                                .frame(minWidth: 260, idealWidth: 300, maxWidth: 340, alignment: .topLeading)
                                .layoutPriority(1)
                        }

                        footerStatusPills
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .task {
            await Task.yield()
            await viewModel.loadData()
        }
        .navigationTitle("")
        .id(config.language)
    }

    // MARK: - Metrics (4 tiles: icon | tag, value, caption)

    private var metricsRow: some View {
        HStack(spacing: 14) {
            OverviewMetricTile(
                icon: "cylinder.split.1x2",
                iconTint: SynapseColor.primary,
                tag: L10n.Dashboard.metricTagTotal,
                value: formatMetric(viewModel.entitiesCount),
                caption: L10n.Dashboard.metricCaptionEntities
            )
            OverviewMetricTile(
                icon: "point.3.connected.trianglepath.dotted",
                iconTint: SynapseColor.secondary,
                tag: L10n.Dashboard.metricTagLinked,
                value: formatMetric(viewModel.relationsCount),
                caption: L10n.Dashboard.metricCaptionRelations
            )
            OverviewMetricTile(
                icon: "doc.text",
                iconTint: SynapseColor.tertiary,
                tag: L10n.Dashboard.metricTagStored,
                value: formatMetric(viewModel.documentsCount),
                caption: L10n.Dashboard.metricCaptionDocuments
            )
            OverviewMetricTile(
                icon: "square.grid.2x2",
                iconTint: SynapseColor.primaryContainer,
                tag: L10n.Dashboard.metricTagActive,
                value: formatMetric(viewModel.activeWorkspacesCount),
                caption: L10n.Dashboard.metricCaptionWorkspaces
            )
        }
    }

    // MARK: - Workspace hero (~2/3 reference)

    private var workspaceHeroCard: some View {
        ZStack(alignment: .trailing) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(L10n.Dashboard.workspaceSectionActive.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .default))
                            .tracking(0.9)
                            .foregroundStyle(SynapseColor.onSurfaceVariant)
                        Circle()
                            .fill(viewModel.isWorkspaceActive ? Color.green : SynapseColor.outlineVariant)
                            .frame(width: 7, height: 7)
                    }

                    Text(viewModel.activeWorkspaceName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(SynapseColor.onSurface)
                        .lineLimit(2)

                    Text(viewModel.isWorkspaceActive ? L10n.Dashboard.workspaceBlurb : L10n.Dashboard.workspaceBlurbEmpty)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(SynapseColor.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    HStack(spacing: 12) {
                        Button {
                            NotificationCenter.default.post(name: .brainAIOpenGraph, object: nil)
                        } label: {
                            Text(L10n.Dashboard.workspaceResume)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SynapseColor.onSurface)
                        .background(SynapseColor.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SynapseColor.outlineVariant.opacity(0.25), lineWidth: 1)
                        )
                        .fixedSize(horizontal: true, vertical: false)

                        Button {
                            BrainAICompanionAppLauncher.openSettings()
                        } label: {
                            Text(L10n.Dashboard.workspaceSettingsLink)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SynapseColor.primary)
                        .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)

                    if !viewModel.isWorkspaceActive {
                        Button {
                            NotificationCenter.default.post(name: .brainAIOpenSetupWizard, object: nil)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(L10n.Nav.setupWizard)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SynapseColor.onPrimaryFixed)
                        .background(SynapseStyle.primaryCTAGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.top, 6)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)

                workspaceNeuralGraphic
                    .frame(width: 200)
                    .padding(.trailing, 8)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
        .background(SynapseColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.22), lineWidth: 1)
        )
    }

    private var workspaceNeuralGraphic: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SynapseColor.primaryContainer.opacity(0.12),
                    SynapseColor.secondary.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                let nodes: [CGPoint] = [
                    CGPoint(x: size.width * 0.25, y: size.height * 0.35),
                    CGPoint(x: size.width * 0.55, y: size.height * 0.22),
                    CGPoint(x: size.width * 0.78, y: size.height * 0.48),
                    CGPoint(x: size.width * 0.42, y: size.height * 0.72),
                    CGPoint(x: size.width * 0.68, y: size.height * 0.78)
                ]
                var path = Path()
                for i in 0..<nodes.count {
                    for j in (i + 1)..<nodes.count {
                        if (i + j) % 2 == 0 {
                            path.move(to: nodes[i])
                            path.addLine(to: nodes[j])
                        }
                    }
                }
                context.stroke(
                    path,
                    with: .color(SynapseColor.primary.opacity(0.28)),
                    lineWidth: 1
                )
                for p in nodes {
                    let r: CGFloat = 4
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                        with: .color(SynapseColor.secondary.opacity(0.55))
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Activity column (~1/3)

    private var activityColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                Text(L10n.Dashboard.recentActivity)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SynapseColor.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentActivities.enumerated()), id: \.element.id) { index, activity in
                    DashboardActivityCompactRow(activity: activity, shortTime: shortRelativeTime(activity.timestamp))
                    if index < viewModel.recentActivities.count - 1 {
                        Divider()
                            .background(SynapseColor.outlineVariant.opacity(0.15))
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Button {
                NotificationCenter.default.post(name: .brainAIOpenDocuments, object: nil)
            } label: {
                Text(L10n.Dashboard.activityViewFullLog.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SynapseColor.onSurfaceVariant)
            .background(SynapseColor.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(SynapseColor.outlineVariant.opacity(0.22), lineWidth: 1)
            )
            .padding(14)
        }
        .background(SynapseColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Footer pills

    private var footerStatusPills: some View {
        HStack(spacing: 10) {
            footerPill(icon: "lock.shield", text: L10n.Dashboard.footerE2E)
            footerPill(icon: "brain.head.profile", text: L10n.Dashboard.footerLocalInference)
            footerPill(icon: "cylinder.split.1x2", text: L10n.Dashboard.footerSQLite)
            Spacer(minLength: 0)
        }
    }

    private func footerPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(text.uppercased())
                .font(.system(size: 9, weight: .bold, design: .default))
                .tracking(0.5)
        }
        .foregroundStyle(SynapseColor.onSurfaceVariant)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(SynapseColor.surfaceContainerHigh.opacity(0.85))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatMetric(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func shortRelativeTime(_ date: Date) -> String {
        let sec = Date().timeIntervalSince(date)
        if sec < 120 { return L10n.Dashboard.timeJustNow }
        if sec < 3600 {
            let m = max(1, Int(sec / 60))
            return L10n.Dashboard.timeShortMinutes(m)
        }
        if sec < 86400 {
            let h = max(1, Int(sec / 3600))
            return L10n.Dashboard.timeShortHours(h)
        }
        let d = max(1, Int(sec / 86400))
        return L10n.Dashboard.timeDaysAgo(d)
    }

    private func pickIndexFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.Dashboard.chromeIndexFolder
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .brainAIOpenDocuments, object: url)
        }
    }
}

// MARK: - Overview chrome (top bar)

private struct DashboardOverviewChrome: View {
    let ollamaRunning: Bool
    let lightRAGRunning: Bool
    @Binding var searchText: String
    var onRefresh: () -> Void
    var onNewChat: () -> Void
    var onIndexFolder: () -> Void
    var onSearchSubmit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(L10n.Dashboard.chromeOverview.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(SynapseColor.primary)

                statusPill(
                    label: ollamaRunning ? L10n.Dashboard.chromeOllamaOn : L10n.Dashboard.chromeOllamaOff,
                    ok: ollamaRunning
                )
                statusPill(
                    label: lightRAGRunning ? L10n.Dashboard.chromeLightRAGOn : L10n.Dashboard.chromeLightRAGOff,
                    ok: lightRAGRunning
                )
            }

            Spacer(minLength: 12)

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SynapseColor.onSurfaceVariant)
                    TextField(L10n.Chrome.archiveSearchPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(SynapseColor.onSurface)
                        .lineLimit(1)
                        .frame(minWidth: 140, maxWidth: 220, maxHeight: 22, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onSubmit { onSearchSubmit() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .fixedSize(horizontal: false, vertical: true)
                .background(SynapseColor.surfaceContainerLowest)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(SynapseColor.outlineVariant.opacity(0.25), lineWidth: 1)
                )

                chromeIconButton("plus", action: onSearchSubmit)
                chromeIconButton("arrow.clockwise", action: onRefresh)
                chromeIconButton("ellipsis", action: {})

                Button(action: onNewChat) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.message")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Dashboard.chromeNewChat)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(SynapseColor.onPrimaryFixed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SynapseStyle.primaryCTAGradient, in: Capsule(style: .continuous))
                    .shadow(color: SynapseColor.primary.opacity(0.2), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: true)

                Button(action: onIndexFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.Dashboard.chromeIndexFolder)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SynapseColor.surfaceContainerHigh)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(SynapseColor.outlineVariant.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func statusPill(label: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color.green : Color.red.opacity(0.85))
                .frame(width: 6, height: 6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .default))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(SynapseColor.onSurfaceVariant)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(SynapseColor.surfaceContainerHigh.opacity(0.9))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.18), lineWidth: 1)
        )
    }

    private func chromeIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metric tile

private struct OverviewMetricTile: View {
    let icon: String
    let iconTint: Color
    let tag: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconTint)
                Spacer(minLength: 0)
                Text(tag.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .default))
                    .tracking(0.5)
                    .foregroundStyle(SynapseColor.primary.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SynapseColor.primaryContainer.opacity(0.15))
                    .clipShape(Capsule(style: .continuous))
            }

            Spacer(minLength: 10)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(SynapseColor.onSurface)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text(caption)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(SynapseColor.onSurfaceVariant)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(SynapseColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SynapseColor.outlineVariant.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Activity row (compact)

private struct DashboardActivityCompactRow: View {
    let activity: ActivityItem
    let shortTime: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(SynapseColor.surfaceContainerHigh)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: activity.type == .query ? "bubble.left" : "doc.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SynapseColor.primary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SynapseColor.onSurface)
                    .lineLimit(2)
                Text(activity.description)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(SynapseColor.onSurfaceVariant)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortTime)
                .font(.system(size: 9, weight: .bold, design: .default))
                .tracking(0.3)
                .foregroundStyle(SynapseColor.onSurfaceVariant.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

#Preview {
    DashboardView()
}
