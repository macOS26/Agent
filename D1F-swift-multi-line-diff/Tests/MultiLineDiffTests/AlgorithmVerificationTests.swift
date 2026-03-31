//
//  AlgorithmVerificationTests.swift
//  MultiLineDiffTests
//
//  Created by Todd Bruss on 5/24/25.
//

import Testing
import Foundation
@testable import MultiLineDiff

struct AlgorithmVerificationTests {
    
    @Test("Verify All Five Algorithm Selection")
    func verifyAlgorithmSelection() throws {
        let source = """
        struct User {
            let id: Int
            let name: String
            let email: String
            
            func validate() -> Bool {
                return !name.isEmpty && email.contains("@")
            }
        }
        """
        
        let destination = """
        struct User {
            let id: UUID
            let fullName: String
            let emailAddress: String
            
            func isValid() -> Bool {
                return !fullName.isEmpty && emailAddress.contains("@")
            }
        }
        """
        
        // Explicitly test Brus algorithm
        let brusResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .zoom)
        print("🔍 Brus Algorithm:")
        print("   Operations count: \(brusResult.operations.count)")
        print("   Operations: \(formatOperations(brusResult))")
        print("   Algorithm used: \(brusResult.metadata?.algorithmUsed ?? .zoom)")
        
        // Explicitly test Todd algorithm
        let toddResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .megatron)
        print("\n🔍 Todd Algorithm:")
        print("   Operations count: \(toddResult.operations.count)")
        print("   Operations: \(formatOperations(toddResult))")
        print("   Algorithm used: \(toddResult.metadata?.algorithmUsed ?? .megatron)")
        
        // Explicitly test Soda algorithm
        let sodaResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .flash)
        print("\n🥤 Soda Algorithm:")
        print("   Operations count: \(sodaResult.operations.count)")
        print("   Operations: \(formatOperations(sodaResult))")
        print("   Algorithm used: \(sodaResult.metadata?.algorithmUsed ?? .flash)")
        
        // Explicitly test Line algorithm
        let lineResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .starscream)
        print("\n📏 Line Algorithm:")
        print("   Operations count: \(lineResult.operations.count)")
        print("   Operations: \(formatOperations(lineResult))")
        print("   Algorithm used: \(lineResult.metadata?.algorithmUsed ?? .starscream)")
        
        // Explicitly test Drew algorithm
        let drewResult = MultiLineDiff.createDiff(source: source, destination: destination, algorithm: .optimus)
        print("\n🎨 Drew Algorithm:")
        print("   Operations count: \(drewResult.operations.count)")
        print("   Operations: \(formatOperations(drewResult))")
        print("   Algorithm used: \(drewResult.metadata?.algorithmUsed ?? .optimus)")
        
        // Test default algorithm selection
        let defaultResult = MultiLineDiff.createDiff(source: source, destination: destination)
        print("\n🔍 Default Algorithm:")
        print("   Operations count: \(defaultResult.operations.count)")
        print("   Operations: \(formatOperations(defaultResult))")
        print("   Algorithm used: \(defaultResult.metadata?.algorithmUsed ?? .zoom)")
        
        // Verify they produce correct results
        let applied1 = try MultiLineDiff.applyDiff(to: source, diff: brusResult)
        let applied2 = try MultiLineDiff.applyDiff(to: source, diff: toddResult)
        let applied3 = try MultiLineDiff.applyDiff(to: source, diff: sodaResult)
        let applied4 = try MultiLineDiff.applyDiff(to: source, diff: lineResult)
        let applied5 = try MultiLineDiff.applyDiff(to: source, diff: drewResult)
        let applied6 = try MultiLineDiff.applyDiff(to: source, diff: defaultResult)
        
        #expect(applied1 == destination, "Brus should produce correct result")
        #expect(applied2 == destination, "Todd should produce correct result")
        #expect(applied3 == destination, "Soda should produce correct result")
        #expect(applied4 == destination, "Line should produce correct result")
        #expect(applied5 == destination, "Drew should produce correct result")
        #expect(applied6 == destination, "Default should produce correct result")
        
        // Algorithm comparison
        print("\n📊 All Algorithm Comparison:")
        print("   Brus operations: \(brusResult.operations.count)")
        print("   Todd operations: \(toddResult.operations.count)")
        print("   Soda operations: \(sodaResult.operations.count)")
        print("   Line operations: \(lineResult.operations.count)")
        print("   Drew operations: \(drewResult.operations.count)")
        print("   Default operations: \(defaultResult.operations.count)")
        
        // Performance characteristics
        print("\n🔬 Algorithm Characteristics:")
        print("   • Brus: Character-based, fast, simple operations")
        print("   • Todd: Line-based, semantic, more detailed operations")
        print("   • Soda: Swift prefix-based, optimized for common patterns")
        print("   • Line: Swift line-based, balanced granularity")
        print("   • Drew: Swift line+diff, Todd-compatible but faster")
    }
} 