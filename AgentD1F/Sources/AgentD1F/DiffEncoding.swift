//
//  DiffEncoding.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//


/// Represents different encoding types for diff serialization
public enum DiffEncoding {
    /// Base64 encoded string representation
    case base64
    /// JSON string representation
    case jsonString
    /// Raw JSON data
    case jsonData
}
