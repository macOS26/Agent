import Foundation
import SwiftSyntax
import SwiftParser
import SwiftRefactor

/// Visitor for detecting potential refactoring opportunities
class RefactoringOpportunityVisitor: SwiftAnalysisVisitor {
    // Track function definitions with their body size
    private var functionBodies: [FunctionDeclSyntax: Int] = [:]
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check if the function has a body
        if let body = node.body {
            // Count the number of statements in the function body
            let statementsCount = body.statements.count
            functionBodies[node] = statementsCount
            
            // Check for very large functions (potential for extraction)
            if statementsCount > 20 {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Function '\(node.name.text)' is very large (\(statementsCount) statements) - consider breaking it into smaller functions",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
            
            // Look for repeated code blocks within the function
            detectRepeatedCodeBlocks(in: body, function: node)
        }
        return .visitChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for large classes
        let memberCount = node.memberBlock.members.count
        if memberCount > 30 {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Class '\(node.name.text)' has \(memberCount) members - consider breaking it into smaller components",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
    
    override func visit(_ node: InheritanceClauseSyntax) -> SyntaxVisitorContinueKind {
        // Check for deep inheritance hierarchies
        if node.inheritedTypes.count > 3 {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Type inherits from \(node.inheritedTypes.count) types - consider using composition over inheritance",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: SourceFileSyntax) {
        // Look for duplicate function implementations
        detectDuplicateFunctions()
    }
    
    private func detectRepeatedCodeBlocks(in body: CodeBlockSyntax, function: FunctionDeclSyntax) {
        var codeBlocks: [String: [Int]] = [:] // Code block -> [Line numbers]
        
        // Convert statements to strings for comparison
        var lineNumber = locationInfo(for: body.leftBrace).line + 1
        
        for statement in body.statements {
            let statementText = statement.trimmed.description
            
            // Skip short statements
            if statementText.count > 20 {
                if let lines = codeBlocks[statementText] {
                    // This is a repeated code block
                    if lines.count == 1 { // Only report the first time we find a duplicate
                        let firstLineNumber = lines[0]
                        let location = locationInfo(for: statement)
                        issues.append(
                            SourceKitIssue(
                                description: "Repeated code block in function '\(function.name.text)' (first seen at line \(firstLineNumber))",
                                line: location.line,
                                column: location.column,
                                severity: "warning"
                            )
                        )
                    }
                    codeBlocks[statementText]?.append(lineNumber)
                } else {
                    codeBlocks[statementText] = [lineNumber]
                }
            }
            
            // Estimate line number for next statement
            lineNumber += statementText.filter { $0 == "\n" }.count + 1
        }
    }
    
    private func detectDuplicateFunctions() {
        // Group functions by body size first to reduce comparison complexity
        var functionsBySize: [Int: [FunctionDeclSyntax]] = [:]
        
        for (function, size) in functionBodies {
            if functionsBySize[size] == nil {
                functionsBySize[size] = []
            }
            functionsBySize[size]?.append(function)
        }
        
        // Compare functions with similar body sizes
        for (_, functions) in functionsBySize {
            guard functions.count > 1 else { continue }
            
            for i in 0..<functions.count {
                for j in (i+1)..<functions.count {
                    let func1 = functions[i]
                    let func2 = functions[j]
                    
                    // Skip comparison if function names are the same (overloads)
                    if func1.name.text == func2.name.text { continue }
                    
                    // Compare function bodies
                    if let body1 = func1.body?.description, let body2 = func2.body?.description {
                        // Simple similarity check (can be improved)
                        let similarity = calculateSimilarity(between: body1, and: body2)
                        
                        if similarity > 0.8 { // 80% similar
                            let location = locationInfo(for: func2)
                            issues.append(
                                SourceKitIssue(
                                    description: "Function '\(func2.name.text)' is very similar to '\(func1.name.text)' (\(Int(similarity * 100))% similar) - consider refactoring",
                                    line: location.line,
                                    column: location.column,
                                    severity: "warning"
                                )
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func calculateSimilarity(between str1: String, and str2: String) -> Double {
        // Very simple similarity metric based on length and character count
        // This could be improved with more sophisticated algorithms
        let length1 = str1.count
        let length2 = str2.count
        
        // If lengths are very different, similarity is low
        if max(length1, length2) > 2 * min(length1, length2) {
            return 0.0
        }
        
        // Count character frequencies in both strings
        var freq1: [Character: Int] = [:]
        var freq2: [Character: Int] = [:]
        
        for char in str1 {
            freq1[char, default: 0] += 1
        }
        
        for char in str2 {
            freq2[char, default: 0] += 1
        }
        
        // Calculate similarity based on character frequency overlap
        var common = 0
        for (char, count1) in freq1 {
            if let count2 = freq2[char] {
                common += min(count1, count2)
            }
        }
        
        return Double(common) / Double(max(length1, length2))
    }
} 