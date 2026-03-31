import Foundation
import SwiftSyntax
import SwiftParser
import SwiftBasicFormat

/// Visitor for checking code style inconsistencies
class CodeStyleVisitor: SwiftAnalysisVisitor {
    private let formatter: BasicFormat
    private let originalSource: String
    
    init(sourceLocationConverter: SourceLocationConverter, originalSource: String) {
        self.formatter = BasicFormat()
        self.originalSource = originalSource
        super.init(sourceLocationConverter: sourceLocationConverter)
    }
    
    override func visitPost(_ node: SourceFileSyntax) {
        // Instead of trying to format the entire file at once, we'll check specific style issues manually
        checkIndentation(node)
        checkLineSpacing(node)
        //checkTrailingWhitespace(node)
    }
    
    private func checkIndentation(_ node: SourceFileSyntax) {
        // Check for inconsistent indentation
        var lastIndent = 0
        var lineNumber = 1
        
        for line in originalSource.split(separator: "\n", omittingEmptySubsequences: false) {
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            
            // Check for odd indentation changes
            if leadingSpaces > 0 && leadingSpaces != lastIndent && 
               leadingSpaces != lastIndent + 2 && leadingSpaces != lastIndent + 4 && 
               leadingSpaces != lastIndent - 2 && leadingSpaces != lastIndent - 4 {
                
                issues.append(
                    SourceKitIssue(
                        description: "Inconsistent indentation - line has \(leadingSpaces) spaces",
                        line: lineNumber,
                        column: 1,
                        severity: "warning"
                    )
                )
            }
            
            // Update for next line
            if !line.isEmpty && !line.allSatisfy({ $0.isWhitespace }) {
                lastIndent = leadingSpaces
            }
            lineNumber += 1
        }
    }
    
    private func checkLineSpacing(_ node: SourceFileSyntax) {
        // Check for inconsistent line spacing between declarations
        var lineNumber = 1
        var emptyLineCount = 0
        var inCommentBlock = false
        
        for line in originalSource.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Track comment blocks
            if trimmed.hasPrefix("/*") {
                inCommentBlock = true
            }
            if trimmed.hasSuffix("*/") {
                inCommentBlock = false
            }
            
            // Skip checking inside multi-line comments
            if !inCommentBlock {
                if trimmed.isEmpty {
                    emptyLineCount += 1
                    // Check for excessive empty lines (more than 2)
                    if emptyLineCount > 2 {
                        issues.append(
                            SourceKitIssue(
                                description: "Excessive empty lines",
                                line: lineNumber,
                                column: 1,
                                severity: "warning"
                            )
                        )
                    }
                } else {
                    emptyLineCount = 0
                }
            }
            
            lineNumber += 1
        }
    }
    
//    private func checkTrailingWhitespace(_ node: SourceFileSyntax) {
//        // Check for trailing whitespace
//        var lineNumber = 1
//        
//        for line in originalSource.split(separator: "\n", omittingEmptySubsequences: false) {
//            let trimmed = line.trimmingCharacters(in: .whitespaces)
//            
//            // If trimming changed the length and line isn't empty, there's trailing whitespace
//            if !line.isEmpty && trimmed.count < line.count && !line.allSatisfy({ $0.isWhitespace }) {
//                issues.append(
//                    SourceKitIssue(
//                        description: "Line contains trailing whitespace",
//                        line: lineNumber,
//                        column: line.count,
//                        severity: "warning"
//                    )
//                )
//            }
//            
//            lineNumber += 1
//        }
//    }
} 
