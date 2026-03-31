import Foundation
import SwiftSyntax
import SwiftParser
import SwiftIDEUtils

/// Visitor for analyzing and checking symbol usage
class SymbolUsageVisitor: SwiftAnalysisVisitor {
    private var symbolReferences: [String: [ReferencedSymbol]] = [:]
    private var declarationMap: [String: Syntax] = [:]
    private var unusedSymbols: [String] = []
    
    // Dictionary mapping deprecated API names to their recommended replacements
    private let deprecatedAPIs: [String: String] = [
        "performSelector": "use Swift closures instead",
        "NSURLConnection": "URLSession",
        "stringByAppendingString": "append()",
        "substringFromIndex": "dropFirst()",
        "substringToIndex": "prefix()",
        "stringByReplacingOccurrencesOfString": "replacingOccurrences(of:with:)"
    ]
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Track variable declarations
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let name = pattern.identifier.text
                declarationMap[name] = Syntax(binding)
            }
        }
        return .visitChildren
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Track function declarations
        let name = node.name.text
        declarationMap[name] = Syntax(node)
        return .visitChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        // Track class declarations
        let name = node.name.text
        declarationMap[name] = Syntax(node)
        return .visitChildren
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Track struct declarations
        let name = node.name.text
        declarationMap[name] = Syntax(node)
        return .visitChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        // Track enum declarations
        let name = node.name.text
        declarationMap[name] = Syntax(node)
        return .visitChildren
    }
    
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        // Track symbol references
        let name = node.baseName.text
        
        // Create a new reference
        let reference = ReferencedSymbol(name: name, node: Syntax(node))
        
        if symbolReferences[name] == nil {
            symbolReferences[name] = []
        }
        symbolReferences[name]?.append(reference)
        
        // Check for deprecated API usage
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
        // Check for deprecated member access
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
    
    override func visitPost(_ node: SourceFileSyntax) {
        // After collecting all references, analyze the usage patterns
        
        // 1. Find unused symbols
        for (name, declaration) in declarationMap {
            if symbolReferences[name]?.count ?? 0 <= 1 { // Only the declaration or no references
                // Skip if it's a public symbol (could be used externally)
                if !isPublic(declaration) {
                    unusedSymbols.append(name)
                    
                    let location = locationInfo(for: declaration)
                    issues.append(
                        SourceKitIssue(
                            description: "Symbol '\(name)' appears to be unused or only referenced in its declaration",
                            line: location.line,
                            column: location.column,
                            severity: "warning"
                        )
                    )
                }
            }
        }
        
        // 2. Find unclear symbol names (too short)
        for (name, declaration) in declarationMap {
            if name.count <= 1 && !["i", "j", "k", "x", "y", "z"].contains(name) { // Common short names
                let location = locationInfo(for: declaration)
                issues.append(
                    SourceKitIssue(
                        description: "Symbol name '\(name)' is too short and may not be descriptive enough",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
        
        // 3. Find symbols with few references (potentially dead code)
        for (name, references) in symbolReferences {
            if let declaration = declarationMap[name] {
                // Skip public symbols, common patterns, and already reported unused symbols
                if !isPublic(declaration) && !unusedSymbols.contains(name) && !["main", "init"].contains(name) {
                    if references.count == 1 {
                        // Only referenced once (besides its declaration)
                        let location = locationInfo(for: declaration)
                        issues.append(
                            SourceKitIssue(
                                description: "Symbol '\(name)' is only referenced once - possible dead code",
                                line: location.line,
                                column: location.column,
                                severity: "info"
                            )
                        )
                    }
                }
            }
        }
    }
    
    private func isPublic(_ node: Syntax) -> Bool {
        // Check if a declaration has public or open access
        if let variableDecl = node.as(VariableDeclSyntax.self) {
            for modifier in variableDecl.modifiers {
                let modifierText = modifier.name.text
                if modifierText == "public" || modifierText == "open" {
                    return true
                }
            }
        } else if let functionDecl = node.as(FunctionDeclSyntax.self) {
            for modifier in functionDecl.modifiers {
                let modifierText = modifier.name.text
                if modifierText == "public" || modifierText == "open" {
                    return true
                }
            }
        } else if let typeDecl = node.as(ClassDeclSyntax.self) {
            for modifier in typeDecl.modifiers {
                let modifierText = modifier.name.text
                if modifierText == "public" || modifierText == "open" {
                    return true
                }
            }
        } else if let typeDecl = node.as(StructDeclSyntax.self) {
            for modifier in typeDecl.modifiers {
                let modifierText = modifier.name.text
                if modifierText == "public" || modifierText == "open" {
                    return true
                }
            }
        } else if let typeDecl = node.as(EnumDeclSyntax.self) {
            for modifier in typeDecl.modifiers {
                let modifierText = modifier.name.text
                if modifierText == "public" || modifierText == "open" {
                    return true
                }
            }
        }
        return false
    }
}

/// Helper struct to represent a symbol reference
struct ReferencedSymbol {
    let name: String
    let node: Syntax
} 