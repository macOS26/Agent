//
//  DiffAlgorithm.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

/// Global algorithm names to eliminate hardcoded strings throughout the project
public struct AlgorithmNames {
    public static let zoom = "Zoom"
    public static let megatron = "Megatron"
    public static let flash = "Flash" // fastest least detailed diff (3-4 ops)
    public static let starscream = "Starscream"
    public static let optimus = "Optimus" // fastest most detailed diff (ops based on number of lines)
    
    /// Legacy names for backward compatibility
    public struct Legacy {
        public static let brus = "Brus"
        public static let soda = "Soda"
        public static let line = "Line"
        public static let todd = "Todd"
        public static let drew = "Drew"
        public static let arrow = "Arrow"
    }
}

/// Represents the available diff algorithms
@frozen public enum DiffAlgorithm: String, Sendable, Codable {
    /// Simple, fast diff algorithm with O(n) time complexity
    case zoom
    /// Detailed, semantic diff algorithm with O(n log n) time complexity
    case megatron
    /// Swift native prefix/suffix algorithm - fastest for most cases  (2x faster than zoom)
    case flash
    /// Swift native line-aware algorithm - fast with detailed line operations
    case starscream
    /// Swift native line-aware with CollectionDifference - Todd-compatible but faster
    case optimus
    /// AI-generated diff with enhanced metadata tracking
    case aigenerated
    
    /// Display name for the algorithm
    public var displayName: String {
        switch self {
        case .zoom: return AlgorithmNames.zoom
        case .megatron: return AlgorithmNames.megatron
        case .flash: return AlgorithmNames.flash
        case .starscream: return AlgorithmNames.starscream
        case .optimus: return AlgorithmNames.optimus
        case .aigenerated: return "AI Generated"
        }
    }
    
    /// Legacy case mapping for backward compatibility
    public static func from(legacy: String) -> DiffAlgorithm? {
        switch legacy.lowercased() {
        case "brus": return .zoom
        case "soda": return .flash
        case "line": return .starscream
        case "todd": return .megatron
        case "drew": return .optimus
        default: return nil
        }
    }
}
