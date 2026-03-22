import Foundation
import os.log

private let gitLog = Logger(subsystem: "Agent.app.toddbruss", category: "GitTools")

// MARK: - Git Tool Helpers
extension AgentViewModel {

    /// Handle git_status tool - uses User LaunchAgent (no TCC required)
    func handleGitStatus(path: String?) async -> String {
        let cmd = CodingService.buildGitStatusCommand(path: path)
        let result = await executeViaUserAgent(command: cmd)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "(no output, exit code: \(result.status))" : result.output
        return output
    }
    
    /// Handle git_diff tool - uses User LaunchAgent (no TCC required)
    func handleGitDiff(path: String?, staged: Bool, target: String?) async -> String {
        let cmd = CodingService.buildGitDiffCommand(path: path, staged: staged, target: target)
        let result = await executeViaUserAgent(command: cmd)
        let output: String
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = staged ? "No staged changes" : "No changes"
        } else if result.output.count > 50_000 {
            output = String(result.output.prefix(50_000)) + "\n...(diff truncated)"
        } else {
            output = result.output
        }
        return output
    }
    
    /// Handle git_log tool - uses User LaunchAgent (no TCC required)
    func handleGitLog(path: String?, count: Int?) async -> String {
        let cmd = CodingService.buildGitLogCommand(path: path, count: count)
        let result = await executeViaUserAgent(command: cmd)
        let output: String
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = "Error: \(result.status == 0 ? "empty log" : "exit code \(result.status)")"
        } else {
            output = result.output
        }
        return output
    }
    
    /// Handle git_commit tool - uses User LaunchAgent (no TCC required)
    func handleGitCommit(path: String?, message: String, files: [String]?) async -> String {
        let cmd = CodingService.buildGitCommitCommand(path: path, message: message, files: files)
        let result = await executeViaUserAgent(command: cmd)
        return result.output.isEmpty ? "(no output, exit code: \(result.status))" : result.output
    }
    
    /// Handle git_branch tool - uses User LaunchAgent (no TCC required)
    func handleGitBranch(path: String?, name: String, checkout: Bool) async -> String {
        let cmd = CodingService.buildGitBranchCommand(path: path, name: name, checkout: checkout)
        let result = await executeViaUserAgent(command: cmd)
        return result.output.isEmpty
            ? (result.status == 0 ? "Created branch '\(name)'" : "Error (exit code: \(result.status))")
            : result.output
    }
    
    /// Handle git_diff_patch tool - uses User LaunchAgent (no TCC required)
    func handleGitDiffPatch(path: String?, patch: String) async -> String {
        let tempName = "agent_patch_\(UUID().uuidString).patch"
        let tempPath = "/tmp/\(tempName)"
        let dir = CodingService.shellEscape(path ?? CodingService.defaultDir)
        let cmd = "cat > \(tempPath) << 'AGENT_PATCH_EOF'\n\(patch)\nAGENT_PATCH_EOF\ncd \(dir) && git apply --verbose \(tempPath); STATUS=$?; rm -f \(tempPath); exit $STATUS"
        let result = await executeViaUserAgent(command: cmd)
        
        let output: String
        if result.status != 0 {
            output = result.output.isEmpty ? "Patch failed (exit code: \(result.status))" : result.output
        } else {
            output = result.output.isEmpty ? "Patch applied successfully" : result.output
        }
        return output
    }
}