import Foundation

// MARK: - URL Extensions

extension URL {
    /// BrainAI Application Support directory
    public static var brainAIApplicationSupport: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0]
        return appSupport.appendingPathComponent("BrainAI")
    }

    /// BrainAI workspaces directory
    public static var brainAIWorkspaces: URL {
        brainAIApplicationSupport.appendingPathComponent("workspaces")
    }

    /// Ensure this directory exists, creating it if necessary
    /// - Throws: Error if directory cannot be created
    public func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: self,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
