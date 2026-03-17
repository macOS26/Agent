# Apple Intelligence Tool Parser

import Foundation

/// Parses tool calls from Apple Intelligence text responses.
/// Apple Intelligence uses plain-text tool calling instead of structured tool_use blocks.
/// Example: `read_file {"file_path": "/path/to/file"}`
struct AppleIntelligenceToolParser {

    /// Extracts tool calls from a text response.
    /// - Parameter text: The model's text response.
    /// - Returns: Array of tool calls in the format expected by TaskExecution.executeToolCall().
    static func extractToolCalls(from text: String) -> [[String: Any]] {
        var toolCalls: [[String: Any]] = []
        let toolNames = AgentTools.toolNames
        
        for toolName in toolNames {
            // Look for pattern: toolName {"param": value, ...}
            guard let nameRange = text.range(of: toolName) else { continue }
            
            // Find the JSON object after the tool name
            let afterName = text[nameRange.upperBound...].trimmingCharacters(in: .whitespaces)
            guard afterName.hasPrefix("{") else { continue }
            
            // Find the matching closing brace
            var braceCount = 0
            var jsonEnd = afterName.startIndex
            for (i, char) in afterName.enumerated() {
                if char == "{" { braceCount += 1 }
                else if char == "}" { braceCount -= 1 }
                if braceCount == 0 {
                    jsonEnd = afterName.index(afterName.startIndex, offsetBy: i)
                    break
                }
            }
            
            let jsonString = String(afterName[afterName.startIndex...jsonEnd])
            guard let jsonData = jsonString.data(using: .utf8),
                  let input = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            // Found a valid tool call
            toolCalls.append([
                "type": "tool_use",
                "id": UUID().uuidString,
                "name": toolName,
                "input": input
            ])
        }
        
        return toolCalls
    }

    /// Validates a tool call's input against the tool's schema.
    /// - Parameters:
    ///   - toolName: The tool name.
    ///   - input: The input parameters.
    /// - Returns: Tuple of (isValid, errorMessage).
    static func validateToolInput(toolName: String, input: [String: Any]) -> (Bool, String?) {
        guard let toolDef = AgentTools.commonTools.first(where: { $0.name == toolName }) else {
            return (false, "Tool '\\(toolName)' not found")
        }
        
        // Check required parameters
        for requiredParam in toolDef.required {
            if input[requiredParam] == nil {
                return (false, "Missing required parameter: '\\(requiredParam)'")
            }
        }
        
        // Check parameter types
        for (paramName, paramValue) in input {
            guard let schema = toolDef.properties[paramName] else {
                return (false, "Unknown parameter: '\\(paramName)'")
            }
            
            let expectedType = schema["type"] as? String ?? "string"
            let actualType = typeName(for: paramValue)
            
            if expectedType == "integer", actualType != "Int" {
                return (false, "Parameter '\\(paramName)' must be an integer")
            } else if expectedType == "number", actualType != "Double" && actualType != "Int" {
                return (false, "Parameter '\\(paramName)' must be a number")
            } else if expectedType == "boolean", actualType != "Bool" {
                return (false, "Parameter '\\(paramName)' must be a boolean")
            } else if expectedType == "array", !(paramValue is [Any]) {
                return (false, "Parameter '\\(paramName)' must be an array")
            }
        }
        
        return (true, nil)
    }

    /// Helper to get the type name of a value.
    private static func typeName(for value: Any) -> String {
        String(describing: type(of: value))
    }

    /// Truncates tool output to prevent context window overflow.
    /// - Parameters:
    ///   - output: The tool output string.
    ///   - maxLines: Maximum number of lines to return.
    /// - Returns: Truncated output with a message if truncated.
    static func truncateOutput(_ output: String, maxLines: Int) -> String {
        let lines = output.components(separatedBy: .newlines)
        guard lines.count > maxLines else { return output }
        
        let truncatedLines = Array(lines.prefix(maxLines))
        return truncatedLines.joined(separator: "\n") + "\n\n... (truncated \(lines.count - maxLines) more lines)"
    }
}