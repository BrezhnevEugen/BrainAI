import Foundation
import Darwin

/// Monitors system resources: RAM, swap, Ollama process memory.
/// Updated on a 15-second interval by the Tray app.
public final class SystemMonitor {

    /// Current system statistics snapshot.
    public struct Stats {
        public let totalRAM: UInt64
        public let usedRAM: UInt64
        public let freeRAM: UInt64
        public let swapTotal: UInt64
        public let swapUsed: UInt64
        public let ollamaRAM: UInt64
        public let timestamp: Date

        public static let zero = Stats(
            totalRAM: 0, usedRAM: 0, freeRAM: 0,
            swapTotal: 0, swapUsed: 0, ollamaRAM: 0,
            timestamp: .now
        )
    }

    /// Latest stats snapshot. Updated by calling `update()`.
    public private(set) var currentStats: Stats = .zero

    public init() {}

    /// Refresh all system statistics.
    public func update() {
        let ram = readRAMUsage()
        let swap = readSwapUsage()
        let ollama = readOllamaMemory()

        currentStats = Stats(
            totalRAM: ram.total,
            usedRAM: ram.used,
            freeRAM: ram.total - ram.used,
            swapTotal: swap.total,
            swapUsed: swap.used,
            ollamaRAM: ollama,
            timestamp: .now
        )
    }

    // MARK: - RAM via host_statistics64

    private func readRAMUsage() -> (total: UInt64, used: UInt64) {
        let totalRAM = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (totalRAM, 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        // Used = active + wired + compressed (inactive is reclaimable)
        let used = active + wired + compressed

        return (totalRAM, min(used, totalRAM))
    }

    // MARK: - Swap via sysctl

    private func readSwapUsage() -> (total: UInt64, used: UInt64) {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)

        guard result == 0 else {
            return (0, 0)
        }

        return (swapUsage.xsu_total, swapUsage.xsu_used)
    }

    // MARK: - Ollama process memory via Process

    private func readOllamaMemory() -> UInt64 {
        // Use `ps` to find Ollama process memory
        // This avoids requiring private APIs or entitlements
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "rss,comm"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }

        var totalKB: UInt64 = 0
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("ollama") {
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                if let rssStr = parts.first, let rss = UInt64(rssStr) {
                    totalKB += rss
                }
            }
        }

        return totalKB * 1024 // Convert KB to bytes
    }
}
