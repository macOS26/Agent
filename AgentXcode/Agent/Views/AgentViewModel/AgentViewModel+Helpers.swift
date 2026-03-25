@preconcurrency import Foundation
import MCPClient

// MARK: - Helper Functions

extension AgentViewModel {

    // MARK: - Consolidated Tool Expansion

    /// Expands consolidated CRUDL tool names (git, agent, applescript_tool, javascript_tool)
    /// into legacy tool names so existing handlers work unchanged.
    static func expandConsolidatedTool(name: String, input: [String: Any]) -> (String, [String: Any]) {
        let action = input["action"] as? String ?? ""
        let newInput = input

        switch name {
        case "git":
            switch action {
            case "status":     return ("git_status", newInput)
            case "diff":       return ("git_diff", newInput)
            case "log":        return ("git_log", newInput)
            case "commit":     return ("git_commit", newInput)
            case "diff_patch": return ("git_diff_patch", newInput)
            case "branch":     return ("git_branch", newInput)
            default:           return ("git_status", newInput)
            }

        case "agent":
            switch action {
            case "list":    return ("list_agents", newInput)
            case "read":    return ("read_agent", newInput)
            case "create":  return ("create_agent", newInput)
            case "update":  return ("update_agent", newInput)
            case "run":     return ("run_agent", newInput)
            case "delete":  return ("delete_agent", newInput)
            case "combine": return ("combine_agents", newInput)
            default:        return ("list_agents", newInput)
            }

        case "applescript_tool":
            switch action {
            case "execute":     return ("run_applescript", newInput)
            case "lookup_sdef": return ("lookup_sdef", newInput)
            case "list":        return ("list_apple_scripts", newInput)
            case "run":         return ("run_apple_script", newInput)
            case "save":        return ("save_apple_script", newInput)
            case "delete":      return ("delete_apple_script", newInput)
            default:            return ("list_apple_scripts", newInput)
            }

        case "javascript_tool":
            switch action {
            case "execute": return ("execute_javascript", newInput)
            case "list":    return ("list_javascript", newInput)
            case "run":     return ("run_javascript", newInput)
            case "save":    return ("save_javascript", newInput)
            case "delete":  return ("delete_javascript", newInput)
            default:        return ("list_javascript", newInput)
            }

        case "file_manager":
            switch action {
            case "read":             return ("read_file", newInput)
            case "write":            return ("write_file", newInput)
            case "edit":             return ("edit_file", newInput)
            case "create":           return ("create_diff", newInput)
            case "apply":            return ("apply_diff", newInput)
            case "list":             return ("list_files", newInput)
            case "search":           return ("search_files", newInput)
            case "read_dir":         return ("read_dir", newInput)
            case "if_to_switch":     return ("if_to_switch", newInput)
            case "extract_function": return ("extract_function", newInput)
            default:                 return ("read_file", newInput)
            }

        case "xcode":
            switch action {
            case "build":            return ("xcode_build", newInput)
            case "run":              return ("xcode_run", newInput)
            case "list_projects":    return ("xcode_list_projects", newInput)
            case "select_project":   return ("xcode_select_project", newInput)
            case "grant_permission": return ("xcode_grant_permission", newInput)
            case "add_file":        return ("xcode_add_file", newInput)
            case "remove_file":     return ("xcode_remove_file", newInput)
            default:                return ("xcode_build", newInput)
            }

        case "web":
            switch action {
            case "open":          return ("web_open", newInput)
            case "find":          return ("web_find", newInput)
            case "click":         return ("web_click", newInput)
            case "type":          return ("web_type", newInput)
            case "execute_js":    return ("web_execute_js", newInput)
            case "get_url":       return ("web_get_url", newInput)
            case "get_title":     return ("web_get_title", newInput)
            case "google_search": return ("web_google_search", newInput)
            case "search":        return ("web_search", newInput)
            default:              return ("web_open", newInput)
            }

        case "selenium":
            switch action {
            case "start":      return ("selenium_start", newInput)
            case "stop":       return ("selenium_stop", newInput)
            case "navigate":   return ("selenium_navigate", newInput)
            case "find":       return ("selenium_find", newInput)
            case "click":      return ("selenium_click", newInput)
            case "type":       return ("selenium_type", newInput)
            case "execute":    return ("selenium_execute", newInput)
            case "screenshot": return ("selenium_screenshot", newInput)
            case "wait":       return ("selenium_wait", newInput)
            default:           return ("selenium_start", newInput)
            }

        case "accessibility":
            // Remap "action" for perform_action to avoid collision with the dispatch "action"
            var mapped = newInput
            if let axAction = mapped["ax_action"] as? String {
                mapped["action"] = axAction
            }
            switch action {
            case "list_windows":      return ("ax_list_windows", mapped)
            case "get_properties":    return ("ax_get_properties", mapped)
            case "perform_action":    return ("ax_perform_action", mapped)
            case "type_text":         return ("ax_type_text", mapped)
            case "click":             return ("ax_click", mapped)
            case "press_key":         return ("ax_press_key", mapped)
            case "screenshot":        return ("ax_screenshot", mapped)
            case "set_properties":    return ("ax_set_properties", mapped)
            case "find_element":      return ("ax_find_element", mapped)
            case "get_children":      return ("ax_get_children", mapped)
            case "check_permission":  return ("ax_check_permission", mapped)
            case "request_permission": return ("ax_request_permission", mapped)
            default:                  return ("ax_list_windows", mapped)
            }

        default:
            return (name, input)
        }
    }

    /// Convert Any to JSONValue, handling arrays and nested objects recursively.
    static func toJSONValue(_ value: Any) -> JSONValue {
        if let s = value as? String { return .string(s) }
        if let i = value as? Int { return .int(i) }
        if let d = value as? Double { return .double(d) }
        if let b = value as? Bool { return .bool(b) }
        if let arr = value as? [Any] { return .array(arr.map { toJSONValue($0) }) }
        if let dict = value as? [String: Any] { return .object(dict.mapValues { toJSONValue($0) }) }
        return .string(String(describing: value))
    }
    
    /// Generate a short name for auto-saving an AppleScript from its source.
    /// Uses the first meaningful words from the script, capped at 40 chars.
    static func autoScriptName(from source: String) -> String {
        let clean = source
            .replacingOccurrences(of: "tell application", with: "")
            .replacingOccurrences(of: "display dialog", with: "dialog")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = clean.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "_")
        let name = words.prefix(40)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return name.isEmpty ? "untitled_\(Int(Date().timeIntervalSince1970))" : String(name)
    }
    
    /// Show first N lines of output, then "..." if there's more.
    static func preview(_ text: String, lines count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count <= count { return text.trimmingCharacters(in: .newlines) }
        return lines.prefix(count).joined(separator: "\n") + "\n..."
    }
    
    /// Wrap text in a markdown code fence with language tag for syntax highlighting.
    static func codeFence(_ text: String, language: String = "") -> String {
        "```\(language)\n\(text.trimmingCharacters(in: .newlines))\n```"
    }
    
    /// Guess language from file extension for syntax highlighting.
    static func langFromPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "m", "mm": return "objc"
        case "java": return "java"
        case "kt": return "kotlin"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "sql": return "sql"
        case "sh", "bash", "zsh": return "bash"
        case "html", "htm": return "html"
        case "css": return "css"
        case "xml", "plist": return "xml"
        default: return ""
        }
    }
    
    /// Validate that a path exists. Returns an error string if invalid, nil if OK.
    static func checkPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "Error: path does not exist: \(path) — check for typos"
        }
        return nil
    }
    
    /// Extract user-directory paths from a shell command for preflight validation.
    /// Catches typos like "/Users/foo/Documets/..." before running the command.
    /// Resolve project folder to a directory (strip filename if path points to a file).
    static func resolvedWorkingDirectory(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue ? path : (path as NSString).deletingLastPathComponent
        }
        // Path doesn't exist yet — treat as directory
        return path
    }
    
    /// Set `PWD` for a shell command when a project folder is set.
    /// Skips if the command already starts with `cd `.
    static func prependWorkingDirectory(_ command: String, projectFolder: String) -> String {
        guard !projectFolder.isEmpty else { return command }
        let dir = resolvedWorkingDirectory(projectFolder)
        guard !dir.isEmpty, dir != "/" else { return command }
        if command.hasPrefix("cd ") { return command }
        let escaped = dir.replacingOccurrences(of: "'", with: "'\\''")
        return "export PWD='\(escaped)'; \(command)"
    }
    
    /// Extract the target directory from a command starting with `cd `.
    /// Resolves relative paths against the current project folder.
    static func extractCdTarget(_ command: String, relativeTo base: String) -> String? {
        guard command.hasPrefix("cd ") else { return nil }
        let afterCd = String(command.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        guard !afterCd.isEmpty else { return nil }
        // Extract path before any && or ;
        let path: String
        if let r = afterCd.range(of: "&&") {
            path = String(afterCd[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else if let r = afterCd.range(of: ";") {
            path = String(afterCd[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            path = afterCd
        }
        // Strip surrounding quotes
        var cleaned = path
        if (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) ||
           (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard !cleaned.isEmpty else { return nil }
        // Expand ~
        if cleaned.hasPrefix("~/") || cleaned == "~" {
            cleaned = (cleaned as NSString).expandingTildeInPath
        }
        // Resolve relative paths against current project folder
        if !cleaned.hasPrefix("/") {
            let baseDir = resolvedWorkingDirectory(base)
            if !baseDir.isEmpty {
                cleaned = (baseDir as NSString).appendingPathComponent(cleaned)
            }
        }
        // Standardize (resolve .., .)
        cleaned = (cleaned as NSString).standardizingPath
        return cleaned
    }
    
    static func preflightCommand(_ command: String) -> String? {
        // Match paths under /Users/ or ~/ — most common source of typos
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:^|\s)(/Users/[^\s'";&|><$]+|~/[^\s'";&|><$]+)"#
        ) else { return nil }
        let nsCmd = command as NSString
        let matches = regex.matches(in: command, range: NSRange(location: 0, length: nsCmd.length))
        for match in matches {
            var path = nsCmd.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            // Strip trailing wildcards/globs for directory validation (e.g. /path/to/*)
            while path.hasSuffix("*") || path.hasSuffix("?") {
                path = String(path.dropLast())
            }
            if path.hasSuffix("/") { path = String(path.dropLast()) }
            guard !path.isEmpty else { continue }
            let expanded = (path as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                return "Error: path does not exist: \(path) — check for typos in the path"
            }
        }
        return nil
    }

    /// Count files at a path.
    private static func countFilesAtPath(_ path: String, hasWildcard: Bool) -> Int {
        let fm: FileManager = FileManager.default
        var isDir: ObjCBool = false

        if hasWildcard {
            let parent: String = (path as NSString).deletingLastPathComponent
            guard fm.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue else { return 0 }
            let contents: [String]? = try? fm.contentsOfDirectory(atPath: parent)
            return contents?.count ?? 0
        }

        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
                var count: Int = 0
                while enumerator.nextObject() != nil {
                    count += 1
                    if count > 10_000 { return count }
                }
                return count
            }
            return 1
        }
        return 0
    }

    // MARK: - Plan Mode

    /// Directory for all plan files.
    private static func planDir(_ projectFolder: String) -> String {
        let base = projectFolder.isEmpty ? NSHomeDirectory() : resolvedWorkingDirectory(projectFolder)
        return (base as NSString).appendingPathComponent("plans")
    }

    /// Resolve the plan file path for a given plan_id.
    private static func planFilePath(_ planId: String, projectFolder: String) -> String {
        return (planDir(projectFolder) as NSString).appendingPathComponent("plan_\(planId).md")
    }

    /// Sanitize a tab name into a safe filename slug.
    static func sanitizeTabName(_ name: String) -> String {
        let slug = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return slug.isEmpty ? "main" : slug
    }

    /// Find the most recent plan file in the plans directory.
    private static func mostRecentPlan(_ projectFolder: String) -> (id: String, path: String)? {
        let dir = planDir(projectFolder)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        let plans = files.filter { $0.hasPrefix("plan_") && $0.hasSuffix(".md") }
        guard !plans.isEmpty else { return nil }
        // Sort by modification date, most recent first
        let sorted = plans.sorted { a, b in
            let pathA = (dir as NSString).appendingPathComponent(a)
            let pathB = (dir as NSString).appendingPathComponent(b)
            let dateA = (try? fm.attributesOfItem(atPath: pathA)[.modificationDate] as? Date) ?? .distantPast
            let dateB = (try? fm.attributesOfItem(atPath: pathB)[.modificationDate] as? Date) ?? .distantPast
            return dateA > dateB
        }
        let filename = sorted[0]
        let id = String(filename.dropFirst(5).dropLast(3)) // strip "plan_" and ".md"
        return (id, (dir as NSString).appendingPathComponent(filename))
    }

    /// Handle plan_mode tool calls: create, update, read, list, or delete.
    /// tabName is used as the plan ID — "main" for the main tab, or the tab's display title.
    static func handlePlanMode(action: String, input: [String: Any], projectFolder: String, tabName: String = "main") -> String {
        let fm = FileManager.default
        let dir = planDir(projectFolder)

        switch action.lowercased() {
        case "create":
            guard let title = input["title"] as? String, !title.isEmpty else {
                return "Error: title is required for plan_mode create"
            }
            guard let stepsRaw = input["steps"] as? String, !stepsRaw.isEmpty else {
                return "Error: steps is required for plan_mode create"
            }
            let planId = input["plan_id"] as? String ?? sanitizeTabName(tabName)
            let steps = stepsRaw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var md = "# \(title)\n\n"
            for (i, step) in steps.enumerated() {
                md += "- [ ] \(i + 1). \(step)\n"
            }
            md += "\n---\n*Status: \(steps.count) steps pending*\n"
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                let path = planFilePath(planId, projectFolder: projectFolder)
                try md.write(toFile: path, atomically: true, encoding: .utf8)
                return "Plan created: \(title) (\(steps.count) steps)\nplan_id: \(planId)\nFile: \(path)"
            } catch {
                return "Error writing plan: \(error.localizedDescription)"
            }

        case "update":
            let stepNum: Int
            if let n = input["step"] as? Int {
                stepNum = n
            } else if let s = input["step"] as? String, let n = Int(s) {
                stepNum = n
            } else {
                return "Error: step number is required for plan_mode update"
            }
            guard stepNum > 0 else { return "Error: step number must be > 0" }
            guard let status = input["status"] as? String else {
                return "Error: status is required for plan_mode update (in_progress, completed, failed)"
            }
            let planId: String
            let path: String
            if let id = input["plan_id"] as? String, !id.isEmpty {
                planId = id
                path = planFilePath(id, projectFolder: projectFolder)
            } else if let recent = mostRecentPlan(projectFolder) {
                planId = recent.id
                path = recent.path
            } else {
                return "Error: no plan found. Use plan_mode create first."
            }
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else {
                return "Error: plan '\(planId)' not found."
            }

            let marker: String
            switch status.lowercased() {
            case "in_progress": marker = "- [⏳]"
            case "completed": marker = "- [✅]"
            case "failed": marker = "- [❌]"
            default: return "Error: invalid status. Use in_progress, completed, or failed."
            }

            var lines = content.components(separatedBy: "\n")
            let target = "\(stepNum)."
            var found = false
            for i in 0..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed.contains(target) && (trimmed.hasPrefix("- [") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [⏳]") || trimmed.hasPrefix("- [❌]")) {
                    if let bracketEnd = lines[i].range(of: "] ") {
                        let rest = String(lines[i][bracketEnd.upperBound...])
                        let indent = String(lines[i].prefix(while: { $0 == " " || $0 == "\t" }))
                        lines[i] = "\(indent)\(marker) \(rest)"
                        found = true
                        break
                    }
                }
            }

            guard found else {
                return "Error: step \(stepNum) not found in plan '\(planId)'."
            }

            let completed = lines.filter { $0.contains("- [✅]") }.count
            let inProgress = lines.filter { $0.contains("- [⏳]") }.count
            let failed = lines.filter { $0.contains("- [❌]") }.count
            let total = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- [") }.count
            let pending = total - completed - inProgress - failed

            if let statusIdx = lines.firstIndex(where: { $0.hasPrefix("*Status:") }) {
                lines[statusIdx] = "*Status: \(completed) done, \(inProgress) in progress, \(failed) failed, \(pending) pending*"
            }

            do {
                try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
                return "[\(planId)] Step \(stepNum) → \(status)"
            } catch {
                return "Error writing plan: \(error.localizedDescription)"
            }

        case "read":
            let path: String
            let planId: String
            if let id = input["plan_id"] as? String, !id.isEmpty {
                planId = id
                path = planFilePath(id, projectFolder: projectFolder)
            } else if let recent = mostRecentPlan(projectFolder) {
                planId = recent.id
                path = recent.path
            } else {
                return "No plans found. Use plan_mode create to start a plan."
            }
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else {
                return "Error: plan '\(planId)' not found."
            }
            return "plan_id: \(planId)\n\(content)"

        case "list":
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
                return "No plans directory found."
            }
            let plans = files.filter { $0.hasPrefix("plan_") && $0.hasSuffix(".md") }.sorted()
            if plans.isEmpty { return "No plans found." }
            return plans.map { filename in
                let id = String(filename.dropFirst(5).dropLast(3))
                let path = (dir as NSString).appendingPathComponent(filename)
                // Read first line for title
                let title: String
                if let data = fm.contents(atPath: path),
                   let content = String(data: data, encoding: .utf8),
                   let firstLine = content.components(separatedBy: "\n").first,
                   firstLine.hasPrefix("# ") {
                    title = String(firstLine.dropFirst(2))
                } else {
                    title = id
                }
                return "\(id): \(title)"
            }.joined(separator: "\n")

        case "delete":
            guard let id = input["plan_id"] as? String, !id.isEmpty else {
                return "Error: plan_id is required for plan_mode delete"
            }
            let path = planFilePath(id, projectFolder: projectFolder)
            guard fm.fileExists(atPath: path) else {
                return "Error: plan '\(id)' not found."
            }
            do {
                try fm.removeItem(atPath: path)
                return "Deleted plan: \(id)"
            } catch {
                return "Error deleting plan: \(error.localizedDescription)"
            }

        default:
            return "Error: invalid action '\(action)'. Use create, update, read, list, or delete."
        }
    }

    // MARK: - Combine Agent Scripts

    /// Merge two Swift script sources: deduplicate imports, handle duplicate scriptMain
    /// by keeping A's entry point and renaming B's body into a helper function.
    static func combineScriptSources(contentA: String, contentB: String, sourceA: String, sourceB: String) -> String {
        let linesA = contentA.components(separatedBy: "\n")
        let linesB = contentB.components(separatedBy: "\n")

        var imports = [String]()
        var seenImports = Set<String>()
        var bodyA = [String]()
        var bodyB = [String]()

        for line in linesA {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("import ") {
                if seenImports.insert(t).inserted { imports.append(line) }
            } else {
                bodyA.append(line)
            }
        }
        for line in linesB {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("import ") {
                if seenImports.insert(t).inserted { imports.append(line) }
            } else {
                bodyB.append(line)
            }
        }

        // Trim leading blank lines
        let trimmedA = Array(bodyA.drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
        var trimmedB = Array(bodyB.drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))

        // Detect duplicate scriptMain in B — remove @_cdecl and rename to helper
        let hasMainA = trimmedA.contains(where: { $0.contains("func scriptMain") || $0.contains("func script_main") })
        let hasMainB = trimmedB.contains(where: { $0.contains("func scriptMain") || $0.contains("func script_main") })

        if hasMainA && hasMainB {
            // Remove @_cdecl line and rename scriptMain in B
            trimmedB = trimmedB.filter { !$0.contains("@_cdecl(\"script_main\")") }
            trimmedB = trimmedB.map { line in
                line.replacingOccurrences(of: "public func scriptMain()", with: "public func scriptMain_\(sourceB)()")
                    .replacingOccurrences(of: "public func script_main()", with: "public func scriptMain_\(sourceB)()")
            }
        }

        return imports.joined(separator: "\n")
            + "\n\n// MARK: - From \(sourceA)\n\n"
            + trimmedA.joined(separator: "\n")
            + "\n\n// MARK: - From \(sourceB)\n\n"
            + trimmedB.joined(separator: "\n")
    }
}