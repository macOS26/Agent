import Foundation
import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacros

/// Visitor for analyzing and validating macro usage
class MacroUsageVisitor: SwiftAnalysisVisitor {
    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        // Check for macro attributes
        if node.attributeName.description.hasPrefix("@") {
            let macroName = node.attributeName.description
            
            // Check for unsupported or invalid arguments for known macros
            validateMacroArguments(node, macroName: macroName)
        }
        
        return .visitChildren
    }
    
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        // Check for macro expansions (like #if, #warning, etc.)
        let macroName = node.macroName.text
        
        // Validate specific macros
        switch macroName {
        case "warning", "error":
            validateCompilerDirective(node, type: macroName)
        case "if", "elseif":
            validateConditionalCompilation(node)
        case "available":
            validateAvailabilityMacro(node)
        default:
            // Custom macros or other standard macros
            break
        }
        
        return .visitChildren
    }
    
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Handle declaration macros
        let macroName = node.macroName.text
        
        // Check for common issues with declaration macros
        if node.trailingClosure == nil && !["sourceLocation", "warning", "error"].contains(macroName) {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Declaration macro '#\(macroName)' might be missing required content or arguments",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
        
        return .visitChildren
    }
    
    // MARK: - Validation Methods
    
    private func validateMacroArguments(_ node: AttributeSyntax, macroName: String) {
        // Known macros with specific validation rules
        switch macroName {
        case "@available":
            validateAvailabilityAttribute(node)
        case "@objc":
            validateObjCAttribute(node)
        case "@MainActor", "@GlobalActor":
            validateActorAttribute(node)
        case "@discardableResult":
            validateDiscardableResultAttribute(node)
        default:
            // Check if using a custom macro
            if node.arguments == nil && !isStandardMacro(macroName) {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Custom macro '\(macroName)' might require arguments",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
    }
    
    private func validateAvailabilityAttribute(_ node: AttributeSyntax) {
        // Check that @available has proper platform arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            if arguments.isEmpty {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "@available attribute must include platform or version information",
                        line: location.line,
                        column: location.column,
                        severity: "error"
                    )
                )
            }
            
            // Check for correct usage of deprecated/obsoleted arguments
            var hasDeprecated = false
            var hasObsoleted = false
            var hasMessage = false
            
            for arg in arguments {
                if arg.label?.text == "deprecated" {
                    hasDeprecated = true
                } else if arg.label?.text == "obsoleted" {
                    hasObsoleted = true
                } else if arg.label?.text == "message" {
                    hasMessage = true
                }
            }
            
            // If deprecated or obsoleted is used, a message is recommended
            if (hasDeprecated || hasObsoleted) && !hasMessage {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "@available with deprecated or obsoleted should include a message",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
    }
    
    private func validateObjCAttribute(_ node: AttributeSyntax) {
        // Check for @objc with name argument
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for arg in arguments {
                if arg.label?.text == "name" {
                    // Check if the name follows Objective-C naming conventions
                    if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self) {
                        let name = stringLiteral.segments.description
                        
                        if name.contains("_") || name.contains("-") {
                            let location = locationInfo(for: arg)
                            issues.append(
                                SourceKitIssue(
                                    description: "@objc name contains characters not typical in Objective-C naming conventions",
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
    
    private func validateActorAttribute(_ node: AttributeSyntax) {
        // Check that @MainActor or @GlobalActor is used on appropriate declarations
        if let parent = node.parent {
            if !parent.is(FunctionDeclSyntax.self) && !parent.is(ClassDeclSyntax.self) &&
               !parent.is(StructDeclSyntax.self) && !parent.is(VariableDeclSyntax.self) {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Actor attribute may be used in an unexpected context",
                        line: location.line,
                        column: location.column,
                        severity: "warning"
                    )
                )
            }
        }
    }
    
    private func validateDiscardableResultAttribute(_ node: AttributeSyntax) {
        // Check that @discardableResult is used only on functions that return a value
        if let parent = node.parent?.as(FunctionDeclSyntax.self) {
            if parent.signature.returnClause == nil {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "@discardableResult used on function with no return value",
                        line: location.line,
                        column: location.column,
                        severity: "error"
                    )
                )
            }
        }
    }
    
    private func validateCompilerDirective(_ node: MacroExpansionExprSyntax, type: String) {
        // Validate #warning and #error directives
        if node.arguments.isEmpty {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "#\(type) directive requires a message",
                    line: location.line,
                    column: location.column,
                    severity: "error"
                )
            )
        }
    }
    
    private func validateConditionalCompilation(_ node: MacroExpansionExprSyntax) {
        // Check that conditional compilation macros have proper conditions
        if node.arguments.isEmpty {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "Conditional compilation macro requires a condition",
                    line: location.line,
                    column: location.column,
                    severity: "error"
                )
            )
        }
    }
    
    private func validateAvailabilityMacro(_ node: MacroExpansionExprSyntax) {
        // Validate #available usage
        if node.parent?.as(IfExprSyntax.self) != nil {
            // This is fine, #available is typically used in if statements
        } else if node.parent?.as(GuardStmtSyntax.self) != nil {
            // This is also a valid usage in guard statements
        } else {
            let location = locationInfo(for: node)
            issues.append(
                SourceKitIssue(
                    description: "#available should be used within an if or guard condition",
                    line: location.line,
                    column: location.column,
                    severity: "warning"
                )
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func isStandardMacro(_ name: String) -> Bool {
        // List of standard Swift attribute macros that don't require arguments
        let standardMacros = [
            "@discardableResult", "@autoclosure", "@escaping", "@frozen", 
            "@objc", "@IBOutlet", "@IBAction", "@IBDesignable", "@IBInspectable",
            "@main", "@testable", "@UIApplicationMain", "@NSApplicationMain",
            "@lazy", "@available", "@inline", "@usableFromInline", "@inlinable"
        ]
        
        return standardMacros.contains(name)
    }
} 