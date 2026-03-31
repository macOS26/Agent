//
//  MultiLineDiff+Calc.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/24/25.
//

extension MultiLineDiff {
    /// Calculate confidence score for section matching using both preceding and following context
    internal static func calculateSectionMatchConfidence(
        sectionText: String,
        precedingContext: String,
        followingContext: String?,
        fullLines: [Substring],
        sectionStartIndex: Int,
        sectionEndIndex: Int
    ) -> Double {
        var confidence = 0.0
        
        // Check preceding context match
        let precedingScore = calculateContextMatchScore(
            context: precedingContext,
            target: sectionText,
            isPrefix: true
        )
        confidence += precedingScore * 0.6 // Weight preceding context more heavily
        
        // Check following context match if available
        if let followingContext = followingContext, !followingContext.isEmpty {
            let followingScore = calculateContextMatchScore(
                context: followingContext,
                target: sectionText,
                isPrefix: false
            )
            confidence += followingScore * 0.4 // Following context gets moderate weight
        }
        
        // Additional scoring based on position and surrounding content
        let positionScore = calculatePositionalContextScore(
            fullLines: fullLines,
            sectionStartIndex: sectionStartIndex,
            sectionEndIndex: sectionEndIndex,
            precedingContext: precedingContext,
            followingContext: followingContext
        )
        confidence += positionScore * 0.2
        
        return Swift.min(confidence, 1.0)
    }

    /// Calculate how well a context matches a target string
    internal static func calculateContextMatchScore(
        context: String,
        target: String,
        isPrefix: Bool
    ) -> Double {
        let contextTrimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetTrimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match gets highest score
        if targetTrimmed.contains(contextTrimmed) || contextTrimmed.contains(targetTrimmed) {
            return 1.0
        }
        
        // Check for partial matches at the beginning or end
        if isPrefix {
            if targetTrimmed.hasPrefix(contextTrimmed) || contextTrimmed.hasPrefix(targetTrimmed) {
                return 0.8
            }
        } else {
            if targetTrimmed.hasSuffix(contextTrimmed) || contextTrimmed.hasSuffix(targetTrimmed) {
                return 0.8
            }
        }
        
        // Calculate similarity based on common words/tokens
        let contextWords = Set(contextTrimmed.split(separator: " "))
        let targetWords = Set(targetTrimmed.split(separator: " "))
        
        guard !contextWords.isEmpty && !targetWords.isEmpty else { return 0.0 }
        
        let commonWords = contextWords.intersection(targetWords)
        let similarity = Double(commonWords.count) / Double(max(contextWords.count, targetWords.count))
        
        return similarity * 0.6 // Partial word matching gets moderate score
    }

    /// Calculate positional context score by examining surrounding lines
    internal static func calculatePositionalContextScore(
        fullLines: [Substring],
        sectionStartIndex: Int,
        sectionEndIndex: Int,
        precedingContext: String,
        followingContext: String?
    ) -> Double {
        var score = 0.0
        
        // Check lines immediately before the section
        if sectionStartIndex > 0 {
            let linesBefore = Array(fullLines[max(0, sectionStartIndex - 2)..<sectionStartIndex])
            let contextBefore = linesBefore.joined(separator: "\n")
            
            if contextBefore.contains(precedingContext.trimmingCharacters(in: .whitespacesAndNewlines)) {
                score += 0.5
            }
        }
        
        // Check lines immediately after the section
        if let followingContext = followingContext,
           !followingContext.isEmpty,
           sectionEndIndex < fullLines.count {
            let linesAfter = Array(fullLines[sectionEndIndex..<min(fullLines.count, sectionEndIndex + 2)])
            let contextAfter = linesAfter.joined(separator: "\n")
            
            if contextAfter.contains(followingContext.trimmingCharacters(in: .whitespacesAndNewlines)) {
                score += 0.5
            }
        }
        
        return score
    }

}
