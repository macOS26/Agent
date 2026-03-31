//
//  DiffApplicationType.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//


/// Represents how a diff should be applied - to full source or truncated source
@frozen public enum DiffApplicationType: String, Sendable, Codable {
    /// Diff designed for complete documents - apply to full source
    case requiresFullSource
    /// Diff designed for partial/truncated content - needs section matching
    case requiresTruncatedSource
}
