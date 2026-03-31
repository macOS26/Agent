import Foundation

/// A reporter that generates detailed analysis reports from SwiftCodeChecker results
public class AnalysisReporter {
    private let issues: [SourceKitIssue]
    private let filePath: String
    
    /// Initialize with a list of issues from a code check
    /// - Parameters:
    ///   - issues: The issues found during code analysis
    ///   - filePath: The path to the file that was analyzed
    public init(issues: [SourceKitIssue], filePath: String) {
        self.issues = issues
        self.filePath = filePath
    }
    
    /// Generate a basic summary report
    /// - Returns: A string containing the report summary
    public func generateSummary() -> String {
        var report = """
        # Swift Code Analysis Report
        
        **File**: \(filePath)
        **Date**: \(Date().formatted())
        **Issues Found**: \(issues.count)
        
        ## Summary
        
        """
        
        // Group issues by severity
        let errors = issues.filter { $0.severity == "error" }
        let warnings = issues.filter { $0.severity == "warning" }
        let infos = issues.filter { $0.severity == "info" }
        
        report += "- **Errors**: \(errors.count)\n"
        report += "- **Warnings**: \(warnings.count)\n"
        report += "- **Info**: \(infos.count)\n\n"
        
        // Group issues by category
        let categories = Dictionary(grouping: issues) { issue -> String in
            if issue.description.contains("syntax") || issue.description.contains("parsing") {
                return "Syntax"
            } else if issue.description.contains("unwrap") {
                return "Force Unwraps"
            } else if issue.description.contains("unused") || issue.description.contains("never used") {
                return "Unused Variables"
            } else if issue.description.contains("immutable") || issue.description.contains("let constant") {
                return "Immutable Assignments"
            } else if issue.description.contains("unreachable") {
                return "Unreachable Code"
            } else if issue.description.contains("operator") || issue.description.contains("precedence") {
                return "Operator Precedence"
            } else if issue.description.contains("style") || issue.description.contains("format") || issue.description.contains("whitespace") {
                return "Code Style"
            } else if issue.description.contains("refactor") || issue.description.contains("similar") || issue.description.contains("duplicate") {
                return "Refactoring Opportunities"
            } else if issue.description.contains("macro") {
                return "Macro Usage"
            } else if issue.description.contains("memory") || issue.description.contains("leak") {
                return "Memory Leaks"
            } else if issue.description.contains("catch") {
                return "Exception Handling"
            } else if issue.description.contains("magic number") {
                return "Magic Numbers"
            } else if issue.description.contains("chaining") {
                return "Optional Chaining"
            } else {
                return "Other Issues"
            }
        }
        
        report += "## Issues by Category\n\n"
        for (category, categoryIssues) in categories.sorted(by: { $0.key < $1.key }) {
            report += "- **\(category)**: \(categoryIssues.count)\n"
        }
        
        return report
    }
    
    /// Generate a detailed report with all issues
    /// - Returns: A string containing the detailed report
    public func generateDetailedReport() -> String {
        var report = generateSummary()
        
        report += "\n\n## Detailed Issues\n\n"
        
        // Sort issues by severity and line number
        let sortedIssues = issues.sorted { 
            if $0.severity != $1.severity {
                // Sort by severity: error > warning > info
                if $0.severity == "error" { return true }
                if $1.severity == "error" { return false }
                if $0.severity == "warning" { return true }
                return false
            }
            // If same severity, sort by line number
            return $0.line < $1.line
        }
        
        // Group by severity for the report
        let errorIssues = sortedIssues.filter { $0.severity == "error" }
        let warningIssues = sortedIssues.filter { $0.severity == "warning" }
        let infoIssues = sortedIssues.filter { $0.severity == "info" }
        
        if !errorIssues.isEmpty {
            report += "### Errors\n\n"
            for issue in errorIssues {
                report += "- **Line \(issue.line)**: \(issue.description)\n"
            }
            report += "\n"
        }
        
        if !warningIssues.isEmpty {
            report += "### Warnings\n\n"
            for issue in warningIssues {
                report += "- **Line \(issue.line)**: \(issue.description)\n"
            }
            report += "\n"
        }
        
        if !infoIssues.isEmpty {
            report += "### Info\n\n"
            for issue in infoIssues {
                report += "- **Line \(issue.line)**: \(issue.description)\n"
            }
        }
        
        return report
    }
    
    /// Save the detailed report to a file
    /// - Parameter outputPath: The path where the report should be saved
    /// - Throws: An error if the file cannot be written
    public func saveReportToFile(outputPath: String) throws {
        let report = generateDetailedReport()
        try report.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
} 