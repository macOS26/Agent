// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftSyntax
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntaxBuilder
import SwiftOperators
import SwiftBasicFormat
import SwiftRefactor
import SwiftIDEUtils
import SwiftSyntaxMacros

public struct SourceKitIssue {
    public let description: String
    public let line: Int
    public let column: Int
    public let severity: String
    
    public init(description: String, line: Int, column: Int, severity: String) {
        self.description = description
        self.line = line
        self.column = column
        self.severity = severity
    }
}

public enum SourceKitError: Error {
    case fileNotFound
    case parseError
    case compilationError
}

// MARK: - Syntax Visitors for Code Analysis

/// Base visitor for Swift syntax analysis
class SwiftAnalysisVisitor: SyntaxVisitor {
    let sourceLocationConverter: SourceLocationConverter
    var issues: [SourceKitIssue] = []
    
    init(sourceLocationConverter: SourceLocationConverter) {
        self.sourceLocationConverter = sourceLocationConverter
        super.init(viewMode: .sourceAccurate)
    }
    
    /// Convert a syntax position to line and column
    func locationInfo(for node: some SyntaxProtocol) -> (line: Int, column: Int) {
        let location = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        return (location.line, location.column)
    }
}

/// Visitor for detecting unused variables
class UnusedVariableVisitor: SwiftAnalysisVisitor {
    private var variableDeclarations: [(name: String, node: PatternBindingSyntax)] = []
    private var variableUsages: Set<String> = []
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let varName = pattern.identifier.text
                variableDeclarations.append((varName, binding))
            }
        }
        return .visitChildren
    }
    
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        variableUsages.insert(node.baseName.text)
        return .visitChildren
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        variableUsages.insert(node.declName.baseName.text)
        return .visitChildren
    }
    
    override func visitPost(_ node: SourceFileSyntax) {
        // After visiting the entire file, check for unused variables
        for (name, binding) in variableDeclarations {
            if !variableUsages.contains(name) {
                // Skip if this is the declaration usage
                let location = locationInfo(for: binding)
                issues.append(
                    SourceKitIssue(
                        description: "Variable '\(name)' declared but never used",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
    }
}

/// Visitor for detecting immutable assignments (assignments to let constants)
class ImmutableAssignmentVisitor: SwiftAnalysisVisitor {
    private var constants: [String] = []
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.bindingSpecifier.text == "let" {
            for binding in node.bindings {
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                    constants.append(pattern.identifier.text)
                }
            }
        }
        return .visitChildren
    }
    
    override func visit(_ node: AssignmentExprSyntax) -> SyntaxVisitorContinueKind {
        // Get the left-hand side (target) of the assignment
        if let target = Syntax(node).children(viewMode: .sourceAccurate).first?.as(DeclReferenceExprSyntax.self) {
            let name = target.baseName.text
            if constants.contains(name) {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Cannot assign to value: '\(name)' is a 'let' constant",
                        line: location.line,
                        column: location.column,
                        severity: "error"
                    )
                )
            }
        }
        return .visitChildren
    }
}

/// Visitor for detecting force unwraps
class ForceUnwrapVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: ForceUnwrapExprSyntax) -> SyntaxVisitorContinueKind {
        let location = locationInfo(for: node)
        issues.append(
            SourceKitIssue(
                description: "Force unwrap operator used which may cause runtime crashes",
                line: location.line,
                column: location.column,
                severity: "warning"
            )
        )
        return .visitChildren
    }
    
    override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind {
        // Check if this is a forced cast (as!)
        if node.questionOrExclamationMark?.tokenKind == .exclamationMark {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Force cast operator 'as!' used which may cause runtime crashes",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
}

/// Visitor for detecting naming convention issues
class NamingConventionVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkTypeName(name: node.name.text, node: node)
        return .visitChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkTypeName(name: node.name.text, node: node)
        return .visitChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkTypeName(name: node.name.text, node: node)
        return .visitChildren
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if let firstChar = name.first, firstChar.isUppercase {
            let location = locationInfo(for: node.name)
            issues.append(
                SourceKitIssue(
                    description: "Function name '\(name)' should start with a lowercase letter (lowerCamelCase)",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let name = pattern.identifier.text
                
                // Check for underscored variables without private access
                if name.hasPrefix("_") && !node.modifiers.contains(where: { $0.name.text == "private" }) {
                    let location = locationInfo(for: pattern)
                    issues.append(
                        SourceKitIssue(
                            description: "Variable '\(name)' starts with underscore but is not marked private",
                            line: location.line,
                            column: location.column,
                            severity: "warning"
                        )
                    )
                }
                
                // Check for SCREAMING_SNAKE_CASE
                if name.uppercased() == name && name.contains("_") {
                    let location = locationInfo(for: pattern)
                    issues.append(
                        SourceKitIssue(
                            description: "Variable '\(name)' uses SCREAMING_SNAKE_CASE which is not Swift convention. Use lowerCamelCase for variables/constants",
                            line: location.line,
                            column: location.column,
                            severity: "warning"
                        )
                    )
                }
            }
        }
        return .visitChildren
    }
    
    private func checkTypeName(name: String, node: some SyntaxProtocol) {
        if let firstChar = name.first, firstChar.isLowercase {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Type name '\(name)' should start with an uppercase letter (UpperCamelCase)",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
    }
}

/// Visitor for detecting magic numbers
class MagicNumberVisitor: SwiftAnalysisVisitor {
    private let exemptNumbers = [0, 1, 2, -1, 100]
    
    override func visit(_ node: IntegerLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        // Skip if inside a variable declaration
        if isInsideVarDecl(node) {
            return .visitChildren
        }
        
        // Try to extract the number value
        let numberText = node.literal.text.replacingOccurrences(of: "_", with: "")
        if let number = Int(numberText), !exemptNumbers.contains(number) {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Magic number '\(number)' found. Consider extracting this as a named constant",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
    
    override func visit(_ node: FloatLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        // Skip if inside a variable declaration
        if isInsideVarDecl(node) {
            return .visitChildren
        }
        
        let location = locationInfo(for: node)
        issues.append(
            SourceKitIssue(
                description: "Magic number '\(node.literal.text)' found. Consider extracting this as a named constant",
                line: location.line,
                column: location.column,
                severity: "warning"
            )
        )
        
        return .visitChildren
    }
    
    private func isInsideVarDecl(_ node: some SyntaxProtocol) -> Bool {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if parent.is(VariableDeclSyntax.self) {
                return true
            }
            current = parent
        }
        return false
    }
}

/// Visitor for detecting unreachable code after return statements
class UnreachableCodeVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: ReturnStmtSyntax) -> SyntaxVisitorContinueKind {
        // Find the parent function or closure that contains this return
        if let parentBlock = findParentBlock(of: node) {
            // Find any statements after this return in the same block
            var foundReturn = false
            
            for stmt in parentBlock {
                if stmt.item.as(ReturnStmtSyntax.self) != nil {
                    foundReturn = true
                    continue
                }
                
                // If we've found a return and this is not a closing brace, it's unreachable
                if foundReturn {
                    // Only report the issue for non-empty, non-comment statements
                    if !stmt.item.trimmedDescription.isEmpty && 
                       !stmt.item.trimmedDescription.hasPrefix("//") {
                        let location = locationInfo(for: stmt)
                        issues.append(
                            SourceKitIssue(
                                description: "Unreachable code detected after return statement",
                                line: location.line,
                                column: location.column,
                                severity: "warning"
                            )
                        )
                        // Only report the first unreachable statement
                        break
                    }
                }
            }
        }
        
        return .visitChildren
    }
    
    private func findParentBlock(of node: some SyntaxProtocol) -> CodeBlockItemListSyntax? {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if let codeBlock = parent.as(CodeBlockSyntax.self) {
                return codeBlock.statements
            }
            current = parent
        }
        return nil
    }
}

/// Visitor for detecting functions with high cyclomatic complexity
class CyclomaticComplexityVisitor: SwiftAnalysisVisitor {
    let complexityThreshold: Int
    private var functionStacks: [(name: String, complexity: Int, node: FunctionDeclSyntax)] = []
    
    init(sourceLocationConverter: SourceLocationConverter, complexityThreshold: Int = 10) {
        self.complexityThreshold = complexityThreshold
        super.init(sourceLocationConverter: sourceLocationConverter)
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Start tracking new function with base complexity of 1
        functionStacks.append((node.name.text, 1, node))
        return .visitChildren
    }
    
    override func visitPost(_ node: FunctionDeclSyntax) {
        // Function is complete, check if its complexity exceeds the threshold
        if let _ = functionStacks.lastIndex(where: { $0.node.id == node.id }),
           let (name, complexity, _) = functionStacks.popLast() {
            if complexity > complexityThreshold {
                let location = locationInfo(for: node.name)
                issues.append(
                    SourceKitIssue(
                        description: "Function '\(name)' has a cyclomatic complexity of \(complexity), which exceeds the threshold of \(complexityThreshold)",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
    }
    
    // Increment complexity for control flow branches
    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
        return .visitChildren
    }
    
    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        // Increment complexity for logical operators
        if node.operator.text == "&&" || node.operator.text == "||" {
            incrementComplexity()
        }
        return .visitChildren
    }
    
    private func incrementComplexity() {
        if var last = functionStacks.popLast() {
            last.complexity += 1
            functionStacks.append(last)
        }
    }
}

/// Visitor for detecting long methods that exceed a line threshold
class LongMethodVisitor: SwiftAnalysisVisitor {
    let lineThreshold: Int
    
    init(sourceLocationConverter: SourceLocationConverter, lineThreshold: Int = 50) {
        self.lineThreshold = lineThreshold
        super.init(sourceLocationConverter: sourceLocationConverter)
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body {
            // Calculate method length by line count
            let startLoc = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
            let endLoc = sourceLocationConverter.location(for: body.endPosition)
            
            let lineCount = endLoc.line - startLoc.line + 1
            
            if lineCount > lineThreshold {
                let location = locationInfo(for: node.name)
                issues.append(
                    SourceKitIssue(
                        description: "Function '\(node.name.text)' is \(lineCount) lines long, which exceeds the recommended maximum of \(lineThreshold) lines",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
        
        return .visitChildren
    }
}

/// Visitor for detecting potential guard usage
class GuardUsageVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        // Only suggest guard if this is an if-let or if-var pattern
        if node.conditions.first?.condition.as(OptionalBindingConditionSyntax.self) != nil {
            // Check if the if block contains an early return
            var hasEarlyReturn = false
            if node.body.statements.last?.item.as(ReturnStmtSyntax.self) != nil {
                hasEarlyReturn = true
            }
            
            // If there's no else clause and the block contains an early return,
            // it's a candidate for guard
            if hasEarlyReturn && node.elseBody == nil {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Consider using guard statement for early return instead of nested if-let",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
        
        return .visitChildren
    }
}

/// Visitor for detecting empty catch blocks
class EmptyCatchVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        // Check if the catch block is empty or only contains comments
        let statements = node.body.statements
        
        if statements.isEmpty || statements.allSatisfy(isEmptyOrComment) {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Empty catch block. Errors should be handled or logged",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
    
    private func isEmptyOrComment(_ statement: CodeBlockItemSyntax) -> Bool {
        let text = statement.trimmedDescription
        return text.isEmpty || text.hasPrefix("//")
    }
}

/// Visitor for detecting memory leaks in closures (capturing self strongly)
class MemoryLeakVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        var hasWeakSelf = false
        
        // Check if closure has a [weak self] or [unowned self] capture
        if let captureItems = node.signature?.capture?.items {
            for item in captureItems {
                if let specifier = item.specifier {
                    // Check directly with the token's text representation 
                    let specifierText = specifier.trimmedDescription
                    if (specifierText == "weak" || specifierText == "unowned") && 
                       item.name.text == "self" {
                        hasWeakSelf = true
                        break
                    }
                }
            }
        }
        
        // Track if there's a reference to self in the body
        let selfReferenceCollector = SelfReferenceCollector(viewMode: .sourceAccurate)
        selfReferenceCollector.walk(node.statements)
        
        // If there's a self reference but no weak self capture, warn about potential retain cycle
        if selfReferenceCollector.hasSelfReference && !hasWeakSelf {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Potential retain cycle: closure uses 'self' strongly. Consider using [weak self] or [unowned self]",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
    
    // Helper visitor to detect self references
    private class SelfReferenceCollector: SyntaxVisitor {
        var hasSelfReference = false
        
        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            if let base = node.base?.as(DeclReferenceExprSyntax.self), base.baseName.text == "self" {
                hasSelfReference = true
                return .skipChildren
            }
            return .visitChildren
        }
        
        override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            if node.baseName.text == "self" {
                hasSelfReference = true
                return .skipChildren
            }
            return .visitChildren
        }
    }
}

/// Visitor for detecting improper empty collection checks
class EmptyCollectionVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        // For the newer SwiftSyntax, we need to examine the parent expression context
        if let parent = node.parent, 
           let leftExpr = Syntax(parent).children(viewMode: .sourceAccurate).first?.as(MemberAccessExprSyntax.self),
           leftExpr.declName.baseName.text == "count",
           let rightExpr = Syntax(parent).children(viewMode: .sourceAccurate).dropFirst(2).first?.as(IntegerLiteralExprSyntax.self),
           rightExpr.literal.text == "0" {
            
            let suggestion: String
            if node.operator.text == "==" {
                suggestion = "isEmpty"
            } else if node.operator.text == "!=" || node.operator.text == ">" {
                suggestion = "!isEmpty"
            } else {
                return .visitChildren
            }
            
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Use '\(suggestion)' instead of comparing count to zero to check for empty collections",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
}

/// Visitor for detecting excessive optional chaining
class OptionalChainingVisitor: SwiftAnalysisVisitor {
    let maxDepth: Int
    
    init(sourceLocationConverter: SourceLocationConverter, maxDepth: Int = 3) {
        self.maxDepth = maxDepth
        super.init(sourceLocationConverter: sourceLocationConverter)
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        // Check if there's optional chaining by looking at the tokens
        let nodeText = node.description
        if nodeText.contains("?.") {
            // Count the optional chain depth by examining the full expression text
            var depth = 1
            
            // Count depth by looking for consecutive optional chain operators
            if let fullExprText = findFullExpressionText(node) {
                depth = fullExprText.components(separatedBy: "?.").count - 1
            }
            
            if depth > maxDepth {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Excessive optional chaining depth (\(depth)). Consider unwrapping optionals or using guard/if let",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
        
        return .visitChildren
    }
    
    private func findFullExpressionText(_ node: SyntaxProtocol) -> String? {
        // Find the top-level expression by walking up the tree
        var current: SyntaxProtocol = node
        while let parent = current.parent, !parent.is(CodeBlockItemSyntax.self) {
            current = parent
        }
        return current.description
    }
}

/// Visitor for detecting string literals that should be localized
class StringLiteralVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        // Skip if inside a variable declaration
        if isInsideVarDecl(node) || isInsideImport(node) || isInsideComment(node) {
            return .visitChildren
        }
        
        // Extract the string content
        let stringContent = node.segments.map { $0.description }.joined()
        
        // Skip empty strings, format strings, and short strings
        if stringContent.isEmpty || 
           stringContent.contains("%") || 
           stringContent.count < 5 ||
           stringContent.allSatisfy({ !$0.isLetter }) {
            return .visitChildren
        }
        
        // Look for user-visible text (sentences, words)
        if stringContent.contains(" ") && stringContent.first?.isLetter == true {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Consider localizing this string literal: \"\(stringContent)\"",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
    
    private func isInsideVarDecl(_ node: some SyntaxProtocol) -> Bool {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if parent.is(VariableDeclSyntax.self) {
                return true
            }
            current = parent
        }
        return false
    }
    
    private func isInsideImport(_ node: some SyntaxProtocol) -> Bool {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if parent.is(ImportDeclSyntax.self) {
                return true
            }
            current = parent
        }
        return false
    }
    
    private func isInsideComment(_ node: some SyntaxProtocol) -> Bool {
        // This is a simple heuristic since comments are typically handled as trivia
        let nodeText = node.description
        return nodeText.hasPrefix("//") || nodeText.hasPrefix("/*")
    }
}

/// Visitor for detecting deprecated API usage
class DeprecatedAPIVisitor: SwiftAnalysisVisitor {
    // Common deprecated APIs
    private let deprecatedAPIs = [
        "UIWebView": "WKWebView",
        "stringByAppendingPathComponent": "appendingPathComponent",
        "NSURLConnection": "URLSession",
        "performSelector": "Swift function calls or closures",
        "CGContextSetRGBFillColor": "setFillColor(_:)",
        "dispatch_async": "DispatchQueue.async",
        "M_PI": "Double.pi"
    ]
    
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if let replacement = deprecatedAPIs[name] {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "'\(name)' is deprecated. Use '\(replacement)' instead",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.declName.baseName.text
        if let replacement = deprecatedAPIs[name] {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "'\(name)' is deprecated. Use '\(replacement)' instead",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        return .visitChildren
    }
}

// MARK: - SwiftCodeChecker Implementation

public class SwiftCodeChecker {
    // Dictionary mapping deprecated API names to their recommended replacements
    private let deprecatedAPIs: [String: String] = [
        "performSelector": "use Swift closures instead",
        "NSURLConnection": "URLSession",
        "stringByAppendingString": "append()",
        "substringFromIndex": "dropFirst()",
        "substringToIndex": "prefix()",
        "stringByReplacingOccurrencesOfString": "replacingOccurrences(of:with:)"
    ]
    
    public init() {}
    
    // Check for syntax errors in Swift code
    public func checkSwiftSyntax(at path: String) throws -> [SourceKitIssue] {
        // Read the file content
        guard let sourceText = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw SourceKitError.fileNotFound
        }
        
        // Parse the Swift file and get diagnostics
        let sourceFile = Parser.parse(source: sourceText)
        let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: sourceFile)
        
        // Create source location converter to map positions to line/column
        let locationConverter = SourceLocationConverter(fileName: path, tree: sourceFile)
        
        // Convert diagnostics to SourceKitIssues
        return diagnostics.map { diagnostic in
            let position = AbsolutePosition(utf8Offset: diagnostic.position.utf8Offset)
            let location = locationConverter.location(for: position)
            
            // Always treat parser diagnostics as errors for Swift syntax
            let severityStr = "error"
            
            return SourceKitIssue(
                description: diagnostic.message,
                line: location.line,
                column: location.column,
                severity: severityStr
            )
        }
    }
    
    // Check for variables that are declared but never used
    public func checkUnusedVariables(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = UnusedVariableVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for assignment to immutable variables (let vs var)
    public func checkImmutableAssignments(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = ImmutableAssignmentVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for unreachable code (code after return, break, continue)
    public func checkUnreachableCode(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = UnreachableCodeVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for functions with high cyclomatic complexity
    public func checkCyclomaticComplexity(at path: String, complexityThreshold: Int = 10) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = CyclomaticComplexityVisitor(
            sourceLocationConverter: locationConverter, 
            complexityThreshold: complexityThreshold
        )
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for methods that are too long (exceed line threshold)
    public func checkLongMethods(at path: String, lineThreshold: Int = 50) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = LongMethodVisitor(
            sourceLocationConverter: locationConverter, 
            lineThreshold: lineThreshold
        )
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for missing guard statements (functions that could use early returns)
    public func checkGuardUsage(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = GuardUsageVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for empty catch blocks
    public func checkEmptyCatchBlocks(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = EmptyCatchVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for potential memory leaks in closures (capturing self strongly)
    public func checkMemoryLeaks(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = MemoryLeakVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for improper empty collection checks (comparing count to zero instead of using isEmpty)
    public func checkEmptyCollectionChecks(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = EmptyCollectionVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for deprecated API usage
    public func checkDeprecatedUsage(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = DeprecatedAPIVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for hardcoded string literals that should be localized
    public func checkStringLiteralHardcoding(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = StringLiteralVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for excessive optional chaining
    public func checkOptionalChainingDepth(at path: String, maxDepth: Int = 3) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = OptionalChainingVisitor(
            sourceLocationConverter: locationConverter,
            maxDepth: maxDepth
        )
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for operator precedence issues
    public func checkOperatorPrecedence(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = OperatorPrecedenceVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for code style issues
    public func checkCodeStyle(at path: String) throws -> [SourceKitIssue] {
        guard let sourceText = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw SourceKitError.fileNotFound
        }
        
        let sourceFile = Parser.parse(source: sourceText)
        let locationConverter = SourceLocationConverter(fileName: path, tree: sourceFile)
        
        let visitor = CodeStyleVisitor(sourceLocationConverter: locationConverter, originalSource: sourceText)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for refactoring opportunities
    public func checkRefactoringOpportunities(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = RefactoringOpportunityVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for symbol usage patterns
    public func checkSymbolUsage(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = SymbolUsageVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Check for macro usage issues
    public func checkMacroUsage(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = MacroUsageVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
    
    // Helper method to parse a Swift file
    private func parseFile(at path: String) throws -> (SourceFileSyntax, SourceLocationConverter) {
        guard let sourceText = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw SourceKitError.fileNotFound
        }
        
        let sourceFile = Parser.parse(source: sourceText)
        let locationConverter = SourceLocationConverter(fileName: path, tree: sourceFile)
        
        return (sourceFile, locationConverter)
    }
    
    // Run all checks at once and combine the results
    public func runAllChecks(at path: String) throws -> [SourceKitIssue] {
        var allIssues: [SourceKitIssue] = []
        
        // Original checkers
        let syntaxIssues = try checkSwiftSyntax(at: path)
        allIssues.append(contentsOf: syntaxIssues)
        
        //let unusedVarIssues = try checkUnusedVariables(at: path)
        //allIssues.append(contentsOf: unusedVarIssues)
        
        let immutableAssignIssues = try checkImmutableAssignments(at: path)
        allIssues.append(contentsOf: immutableAssignIssues)
        
        //let unreachableIssues = try checkUnreachableCode(at: path)
        //allIssues.append(contentsOf: unreachableIssues)
        
        // Previously added checkers
        let complexityIssues = try checkCyclomaticComplexity(at: path)
        allIssues.append(contentsOf: complexityIssues)
        
        let forceUnwrapIssues = try checkForceUnwraps(at: path)
        allIssues.append(contentsOf: forceUnwrapIssues)
        
        //let longMethodIssues = try checkLongMethods(at: path)
        //allIssues.append(contentsOf: longMethodIssues)
        
        let guardIssues = try checkGuardUsage(at: path)
        allIssues.append(contentsOf: guardIssues)
        
        //let magicNumberIssues = try checkMagicNumbers(at: path)
        //allIssues.append(contentsOf: magicNumberIssues)
        
        //let namingIssues = try checkNamingConventions(at: path)
        //allIssues.append(contentsOf: namingIssues)
        
        let emptyCatchIssues = try checkEmptyCatchBlocks(at: path)
        allIssues.append(contentsOf: emptyCatchIssues)
        
        let memoryLeakIssues = try checkMemoryLeaks(at: path)
        allIssues.append(contentsOf: memoryLeakIssues)
        
        let emptyCollectionIssues = try checkEmptyCollectionChecks(at: path)
        allIssues.append(contentsOf: emptyCollectionIssues)
        
        let deprecatedIssues = try checkDeprecatedUsage(at: path)
        allIssues.append(contentsOf: deprecatedIssues)
        
        //let stringLiteralIssues = try checkStringLiteralHardcoding(at: path)
        //allIssues.append(contentsOf: stringLiteralIssues)
        
        let optionalChainingIssues = try checkOptionalChainingDepth(at: path)
        allIssues.append(contentsOf: optionalChainingIssues)
        
        // New checkers using advanced SwiftSyntax packages
        let operatorPrecedenceIssues = try checkOperatorPrecedence(at: path)
        allIssues.append(contentsOf: operatorPrecedenceIssues)
        
//        let codeStyleIssues = try checkCodeStyle(at: path)
//        allIssues.append(contentsOf: codeStyleIssues)
        
        let refactoringIssues = try checkRefactoringOpportunities(at: path)
        allIssues.append(contentsOf: refactoringIssues)
        
        let symbolUsageIssues = try checkSymbolUsage(at: path)
        allIssues.append(contentsOf: symbolUsageIssues)
        
        let macroUsageIssues = try checkMacroUsage(at: path)
        allIssues.append(contentsOf: macroUsageIssues)
        
        return allIssues
    }

    // Check for force unwrap operators that could cause runtime crashes
    public func checkForceUnwraps(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = ForceUnwrapVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }

    // Check for "magic numbers" - numerical literals that should be constants
    public func checkMagicNumbers(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = MagicNumberVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }

    // Check for Swift naming convention violations
    public func checkNamingConventions(at path: String) throws -> [SourceKitIssue] {
        let (sourceFile, locationConverter) = try parseFile(at: path)
        
        let visitor = NamingConventionVisitor(sourceLocationConverter: locationConverter)
        visitor.walk(sourceFile)
        
        return visitor.issues
    }
}
