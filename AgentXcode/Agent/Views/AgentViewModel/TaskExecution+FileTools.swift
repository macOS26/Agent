import Foundation
import MultiLineDiff
import os.log

private let fileLog = Logger(subsystem: "Agent.app.toddbruss", category: "FileTools")

// MARK: - File Operation Tools (for Native Tool Handler)
extension AgentViewModel {

    // MARK: - Native File Tool Handlers

    /// Handle read_file tool for native tools
    func handleReadFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let offset = input["offset"] as? Int
        let limit = input["limit"] as? Int

        return await Self.offMain {
            return CodingService.readFile(path: filePath, offset: offset, limit: limit)
        }
    }

    /// Handle write_file tool for native tools
    func handleWriteFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let content = input["content"] as? String ?? ""

        return await Self.offMain {
            return CodingService.writeFile(path: filePath, content: content)
        }
    }

    /// Handle edit_file tool for native tools
    func handleEditFile(input: [String: Any]) async -> String {
        let filePath = input["file_path"] as? String ?? ""
        let oldString = input["old_string"] as? String ?? ""
        let newString = input["new_string"] as? String ?? ""
        let replaceAll = input["replace_all"] as? Bool ?? false

        return await Self.offMain {
            CodingService.editFile(path: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll)
        }
    }
}
