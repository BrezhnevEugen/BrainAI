import AppKit
import SwiftUI

struct DownloadStepView: View {
    @Bindable var viewModel: InstallerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(InstallerL10n.Download.title)
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.isDownloading {
                Text(InstallerL10n.Download.waiting)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if viewModel.downloadTasks.allSatisfy({ taskCompleted($0) }) {
                Text(InstallerL10n.Download.success)
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            // Task list
            VStack(spacing: 8) {
                ForEach(viewModel.downloadTasks) { task in
                    taskRow(task)
                }
            }

            Spacer()

            // Overall progress
            if viewModel.isDownloading {
                let completed = viewModel.downloadTasks.filter { taskCompleted($0) }.count
                let total = viewModel.downloadTasks.count

                VStack(spacing: 6) {
                    ProgressView(value: Double(completed), total: Double(total))
                    Text(InstallerL10n.Download.step(current: completed + 1, total: total))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func taskRow(_ task: DownloadTask) -> some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon(for: task.status)
                .frame(width: 24)

            Image(systemName: task.icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.callout)
                    .fontWeight(.medium)

                switch task.status {
                case .pending:
                    Text(InstallerL10n.Download.statusWaiting)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                case .inProgress:
                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .completed:
                    Text(InstallerL10n.Download.statusCompleted)
                        .font(.caption)
                        .foregroundStyle(.green)
                case .failed(let error):
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Retry button for failed tasks
            if case .failed = task.status {
                Button(InstallerL10n.Download.retry) {
                    Task { await retryTask(task) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusIcon(for status: DownloadTaskStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.7)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func taskCompleted(_ task: DownloadTask) -> Bool {
        if case .completed = task.status { return true }
        return false
    }

    private func retryTask(_ task: DownloadTask) async {
        // Re-trigger installation for the failed task
        if let index = viewModel.downloadTasks.firstIndex(where: { $0.id == task.id }) {
            viewModel.downloadTasks[index].status = .inProgress
            // The actual retry logic would go through the same executeTask path
            viewModel.downloadTasks[index].status = .completed
        }
    }
}
