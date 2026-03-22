@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log

private let taskLog = Logger(subsystem: "Agent.app.toddbruss", category: "FileOperations")

// MARK: - File and Git Operations

extension AgentViewModel {
    
    // MARK: - File Operations for Apple AI
    
    /// Handle file operation tool calls for Apple AI
    func handleFileOperationTool(_ name: String, input: sending [String: Any]) async -> String {
        // read_file
        if name == "read_file" {
            let filePath = input["file_path"] as? String ?? ""
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            return await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
        }
        
        // write_file
        if name == "write_file" {
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            return await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
        }
        
        // edit_file
        if name == "edit_file" {
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            return await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }
        }
        
        // create_diff
        if name == "create_diff" {
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            return await Self.offMain { CodingService.createDiff(source: source, destination: destination) }
        }
        
        // apply_diff
        if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let diff = input["diff"] as? String ?? ""
            return await Self.offMain { CodingService.applyDiff(path: filePath, diff: diff) }
        }
        
        // list_files
        if name == "list_files" {
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String
            return await Self.offMain { CodingService.listFiles(pattern: pattern, path: path) }
        }
        
        // search_files
        if name == "search_files" {
            let pattern = input["pattern"] as? String ?? ""
            let include = input["include"] as? String
            let path = input["path"] as? String
            return await Self.offMain { CodingService.searchFiles(pattern: pattern, include: include, path: path) }
        }
        
        // Tool not found in file operations
        return ""
    }
    
    // MARK: - Git Operations for Apple AI
    
    /// Handle git operation tool calls for Apple AI
    func handleGitOperationTool(_ name: String, input: sending [String: Any]) async -> String {
        // git_status
        if name == "git_status" {
            let path = input["path"] as? String
            return await Self.offMain { CodingService.gitStatus(path: path) }
        }
        
        // git_diff
        if name == "git_diff" {
            let path = input["path"] as? String
            let target = input["target"] as? String
            let staged = input["staged"] as? Bool ?? false
            return await Self.offMain { CodingService.gitDiff(path: path, target: target, staged: staged) }
        }
        
        // git_log
        if name == "git_log" {
            let path = input["path"] as? String
            let count = input["count"] as? Int
            return await Self.offMain { CodingService.gitLog(path: path, count: count) }
        }
        
        // git_commit
        if name == "git_commit" {
            let message = input["message"] as? String ?? ""
            let files = input["files"] as? [String]
            let path = input["path"] as? String
            return await Self.offMain { CodingService.gitCommit(message: message, files: files, path: path) }
        }
        
        // git_diff_patch
        if name == "git_diff_patch" {
            let patch = input["patch"] as? String ?? ""
            let path = input["path"] as? String
            return await Self.offMain { CodingService.gitDiffPatch(patch: patch, path: path) }
        }
        
        // git_branch
        if name == "git_branch" {
            let name = input["name"] as? String ?? ""
            let checkout = input["checkout"] as? Bool ?? true
            let path = input["path"] as? String
            return await Self.offMain { CodingService.gitBranch(name: name, checkout: checkout, path: path) }
        }
        
        // Tool not found in git operations
        return ""
    }
    
    // MARK: - File Operations for Other LLM Providers
    
    /// Handle file operation tool calls for other LLM providers (Claude, Ollama, etc.)
    func handleFileOperationToolForLLM(_ name: String, input: sending [String: Any], toolId: String) async -> (output: String, commandsRun: [String]) {
        var commandsRun: [String] = []
        var output = ""
        
        if name == "read_file" {
            let filePath = input["file_path"] as? String ?? ""
            let offset = input["offset"] as? Int
            let limit = input["limit"] as? Int
            appendLog("📖 Read: \(filePath)")
            output = await Self.offMain { CodingService.readFile(path: filePath, offset: offset, limit: limit) }
            let lang = Self.langFromPath(filePath)
            appendLog(Self.codeFence(Self.preview(output, lines: readFilePreviewLines), language: lang))
        }
        
        else if name == "write_file" {
            let filePath = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            appendLog("📝 Write: \(filePath)")
            output = await Self.offMain { CodingService.writeFile(path: filePath, content: content) }
            appendLog(output)
            commandsRun.append("write_file: \(filePath)")
        }
        
        else if name == "edit_file" {
            let filePath = input["file_path"] as? String ?? ""
            let oldString = input["old_string"] as? String ?? ""
            let newString = input["new_string"] as? String ?? ""
            let replaceAll = input["replace_all"] as? Bool ?? false
            appendLog("✏️ Edit: \(filePath)")
            output = await Self.offMain { CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll) }
            appendLog(output)
            commandsRun.append("edit_file: \(filePath)")
        }
        
        else if name == "create_diff" {
            let source = input["source"] as? String ?? ""
            let destination = input["destination"] as? String ?? ""
            appendLog("📊 Create diff")
            output = await Self.offMain { CodingService.createDiff(source: source, destination: destination) }
            appendLog(Self.codeFence(output, language: "diff"))
        }
        
        else if name == "apply_diff" {
            let filePath = input["file_path"] as? String ?? ""
            let diff = input["diff"] as? String ?? ""
            appendLog("📋 Apply diff: \(filePath)")
            output = await Self.offMain { CodingService.applyDiff(path: filePath, diff: diff) }
            appendLog(output)
            commandsRun.append("apply_diff: \(filePath)")
        }
        
        else if name == "list_files" {
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String
            appendLog("📁 List files: \(pattern)")
            output = await Self.offMain { CodingService.listFiles(pattern: pattern, path: path) }
            appendLog(output)
        }
        
        else if name == "search_files" {
            let pattern = input["pattern"] as? String ?? ""
            let include = input["include"] as? String
            let path = input["path"] as? String
            appendLog("🔍 Search files: \(pattern)")
            output = await Self.offMain { CodingService.searchFiles(pattern: pattern, include: include, path: path) }
            appendLog(output)
        }
        
        return (output, commandsRun)
    }
    
    // MARK: - Git Operations for Other LLM Providers
    
    /// Handle git operation tool calls for other LLM providers (Claude, Ollama, etc.)
    func handleGitOperationToolForLLM(_ name: String, input: sending [String: Any], toolId: String) async -> (output: String, commandsRun: [String]) {
        var commandsRun: [String] = []
        var output = ""
        
        if name == "git_status" {
            let path = input["path"] as? String
            appendLog("📊 Git status")
            output = await Self.offMain { CodingService.gitStatus(path: path) }
            appendLog(output)
        }
        
        else if name == "git_diff" {
            let path = input["path"] as? String
            let target = input["target"] as? String
            let staged = input["staged"] as? Bool ?? false
            appendLog("📊 Git diff")
            output = await Self.offMain { CodingService.gitDiff(path: path, target: target, staged: staged) }
            appendLog(output)
        }
        
        else if name == "git_log" {
            let path = input["path"] as? String
            let count = input["count"] as? Int
            appendLog("📜 Git log")
            output = await Self.offMain { CodingService.gitLog(path: path, count: count) }
            appendLog(output)
        }
        
        else if name == "git_commit" {
            let message = input["message"] as? String ?? ""
            let files = input["files"] as? [String]
            let path = input["path"] as? String
            appendLog("💾 Git commit: \(message)")
            output = await Self.offMain { CodingService.gitCommit(message: message, files: files, path: path) }
            appendLog(output)
            commandsRun.append("git_commit: \(message)")
        }
        
        else if name == "git_diff_patch" {
            let patch = input["patch"] as? String ?? ""
            let path = input["path"] as? String
            appendLog("📋 Git apply patch")
            output = await Self.offMain { CodingService.gitDiffPatch(patch: patch, path: path) }
            appendLog(output)
            commandsRun.append("git_diff_patch")
        }
        
        else if name == "git_branch" {
            let name = input["name"] as? String ?? ""
            let checkout = input["checkout"] as? Bool ?? true
            let path = input["path"] as? String
            appendLog("🌿 Git branch: \(name)")
            output = await Self.offMain { CodingService.gitBranch(name: name, checkout: checkout, path: path) }
            appendLog(output)
            commandsRun.append("git_branch: \(name)")
        }
        
        return (output, commandsRun)
    }
}