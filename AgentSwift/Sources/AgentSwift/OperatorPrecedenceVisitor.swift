import Foundation
import SwiftSyntax
import SwiftOperators
import SwiftParser

/// Visitor for detecting potentially confusing operator precedence
class OperatorPrecedenceVisitor: SwiftAnalysisVisitor {
    private let operatorTable: OperatorTable
    
    override init(sourceLocationConverter: SourceLocationConverter) {
        // Initialize with Swift's standard operator table
        self.operatorTable = OperatorTable.standardOperators
        super.init(sourceLocationConverter: sourceLocationConverter)
    }
    
    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        // Binary expressions without parentheses could have precedence issues
        if let parent = node.parent?.as(InfixOperatorExprSyntax.self) {
            // If this operator is inside a more complex expression
            if let grandParent = parent.parent?.as(SequenceExprSyntax.self) {
                if grandParent.elements.count > 3 { // More than one operator being used
                    // This is a sequence with multiple operators without explicit parentheses
                    let location = locationInfo(for: node)
                    issues.append(
                        SourceKitIssue(
                            description: "Consider adding explicit parentheses to clarify operator precedence",
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
    
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        // Look for sequences with multiple operators that could be ambiguous
        if node.elements.count > 3 {
            // Check if there's a mix of arithmetic and logical operators
            var hasLogical = false
            var hasArithmetic = false
            
            for element in node.elements {
                if let op = element.as(BinaryOperatorExprSyntax.self) {
                    let operatorText = op.operator.text
                    if ["&&", "||"].contains(operatorText) {
                        hasLogical = true
                    } else if ["+", "-", "*", "/", "%"].contains(operatorText) {
                        hasArithmetic = true
                    }
                }
            }
            
            if hasLogical && hasArithmetic {
                let location = locationInfo(for: node)
                issues.append(
                    SourceKitIssue(
                        description: "Mixed logical and arithmetic operators - use parentheses to clarify precedence",
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