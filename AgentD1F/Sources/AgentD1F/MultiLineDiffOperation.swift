//
//  MultiLineDiffOperation.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

@frozen public enum DiffOperation: Sendable, Equatable, Codable {
    case retain(Int)      // Keep a number of characters from the source
    case insert(String)   // Insert new content
    case delete(Int)      // Delete a number of characters from the source
    
    @_optimize(speed)
    public var description: String {
        switch self {
        case .retain(let count): "retain \(count) character\(count.isPlural ? "s" : "")"
        case .insert(let text): "insert \"\(text.truncated(to: 20))\""
        case .delete(let count): "delete \(count) character\(count.isPlural ? "s" : "")"
        }
    }
    
    /// Custom Codable implementation to preserve operation type
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        switch (
            container.contains(.retain),
            container.contains(.insert),
            container.contains(.delete)
        ) {
        case (true, false, false):
            let retainValue = try container.decode(Int.self, forKey: .retain)
            self = .retain(retainValue)
        
        case (false, true, false):
            let insertValue = try container.decode(String.self, forKey: .insert)
            self = .insert(insertValue)
        
        case (false, false, true):
            let deleteValue = try container.decode(Int.self, forKey: .delete)
            self = .delete(deleteValue)
        
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode DiffOperation: Invalid or multiple keys"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .retain(let count):
            try container.encode(count, forKey: .retain)
        case .insert(let text):
            try container.encode(text, forKey: .insert)
        case .delete(let count):
            try container.encode(count, forKey: .delete)
        }
    }
    
    public enum CodingKeys: String, CodingKey {
        case retain = "="
        case insert = "+"
        case delete = "-"
    }
}
