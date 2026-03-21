//
//  DiffToText.swift
//  MultiLineDiff
//
//  Created by Todd Bruss on 5/25/25.
//

import Foundation
import SwiftUI

// MARK: - Centralized Emoji Symbol Definitions
public struct DiffSymbols {
    public static let retain = "📎"
    public static let delete = "❌"
    public static let insert = "✅"
    public static let unknown = "❓"
}

struct DiffLine: Identifiable {
    let id = UUID()
    let content: String
    let type: DiffLineType
}

enum DiffLineType {
    case retain
    case insert
    case delete
    case unchanged
}

enum DiffOperationToText {
    case retain
    case delete
    case insert
    case unknown
    
    var rawValue: String {
        switch self {
        case .retain: return DiffSymbols.retain
        case .delete: return DiffSymbols.delete
        case .insert: return DiffSymbols.insert
        case .unknown: return DiffSymbols.unknown
        }
    }
    
    init(from operation: String) {
        guard let firstChar = operation.first?.description else {
            self = .unknown
            return
        }
        
        switch firstChar {
        case DiffSymbols.retain:
            self = .retain
        case DiffSymbols.delete:
            self = .delete
        case DiffSymbols.insert:
            self = .insert
        default:
            self = .unknown
        }
    }
    
    var textColor: Color {
        switch self {
        case .retain: return .blue
        case .delete: return .red
        case .insert: return .green
        case .unknown: return .primary
        }
    }
    
    var numberBackground: Color {
        switch self {
        case .retain: return .blue
        case .delete: return .red
        case .insert: return .green
        case .unknown: return .gray
        }
    }
    
    var background: Color {
        switch self {
        case .retain: return Color(red: 0.1, green: 0.1, blue: 0.3)
        case .delete: return Color(red: 0.3, green: 0.1, blue: 0.1)
        case .insert: return Color(red: 0.1, green: 0.3, blue: 0.1)
        case .unknown: return Color.gray.opacity(0.1)
        }
    }
}

struct DiffOperationToTextModel {
    let operation: String
    let index: Int
    
    var style: DiffOperationToText {
        DiffOperationToText(from: operation)
    }
    
    var symbol: String {
        style.rawValue
    }
    
    var description: String {
        String(operation.dropFirst())
    }
    
    var textColor: Color {
        style.textColor
    }
    
    var numberBackground: Color {
        style.numberBackground
    }
    
    var background: Color {
        style.background
    }
}

// Alias for compatibility with SwiftUI code
typealias DiffOperationModel = DiffOperationToTextModel

class DiffProcessor {
    static func generateDetailDiffLines(from diffResult: DiffResult, sourceText: String) -> [String] {
        var result: [String] = []
        var sourceIndex = 0
        
        for operation in diffResult.operations {
            switch operation {
            case .retain(let count):
                let retainText = StringHelper.extractSubstring(
                    from: sourceText,
                    start: sourceIndex,
                    length: count
                )
                // Use prefixLines to format each line with retain symbol
                let prefixLines = StringHelper.prefixLines(retainText, with: DiffSymbols.retain)
                // Split into individual lines and add to result
                prefixLines.enumerateLines { line, _ in
                    if !line.isEmpty {
                        result.append(line)
                    }
                }
                sourceIndex += count
                
            case .delete(let count):
                let deleteText = StringHelper.extractSubstring(
                    from: sourceText,
                    start: sourceIndex,
                    length: count
                )
                // Use prefixLines to format each line with delete symbol
                let prefixLines = StringHelper.prefixLines(deleteText, with: DiffSymbols.delete)
                // Split into individual lines and add to result
                prefixLines.enumerateLines { line, _ in
                    if !line.isEmpty {
                        result.append(line)
                    }
                }
                sourceIndex += count
                
            case .insert(let insertText):
                // Use prefixLines to format each line with insert symbol
                let prefixLines = StringHelper.prefixLines(insertText, with: DiffSymbols.insert)
                // Split into individual lines and add to result
                prefixLines.enumerateLines { line, _ in
                    if !line.isEmpty {
                        result.append(line)
                    }
                }
            }
        }
        
        return result
    }
    
    private static func processOperation(type: String, text: String,
                                         detailLines: inout [String],
                                         debugText: inout String) {
        let prefixLines = StringHelper.prefixLines(text, with: type)
        detailLines.append("\(type)\(text)")
        debugText += prefixLines
    }
}

struct StringHelper {
    static func extractSubstring(from text: String, start: Int, length: Int) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(startIndex, offsetBy: length)
        return String(text[startIndex..<endIndex])
    }
    
    static func prefixLines(_ text: String, with prefix: String) -> String {
        var result = ""
        text.enumerateLines { line, _ in
            result.append("\(prefix) \(line)\n")
        }
        return result
    }
}

class DiffViewModel: ObservableObject {
    @Published var sourceText: String = """
    class UserManager {
        private var users: [String: User] = [:]
        
        func addUser(name: String, email: String) -> Bool {
            guard !name.isEmpty && !email.isEmpty else {
                return false
            }
            
            let user = User(name: name, email: email)
            users[email] = user
            return true
        }
        
        func getUser(by email: String) -> User? {
            return users[email]
        }
        
        func removeUser(email: String) {
            users.removeValue(forKey: email)
        }
        
        func getAllUsers() -> [User] {
            return Array(users.values)
        }
    }
    
    struct User {
        let name: String
        let email: String
    }
    """
    
    @Published var destinationText: String = """
    class UserManager {
        private var users: [String: User] = [:]
        private var userCount: Int = 0
        
        func addUser(name: String, email: String, age: Int = 0) -> Result<User, UserError> {
            guard !name.isEmpty && !email.isEmpty else {
                return .failure(.invalidInput)
            }
            
            guard !users.keys.contains(email) else {
                return .failure(.userAlreadyExists)
            }
            
            let user = User(id: UUID(), name: name, email: email, age: age)
            users[email] = user
            userCount += 1
            return .success(user)
        }
        
        func getUser(by email: String) -> User? {
            return users[email]
        }
        
        func removeUser(email: String) -> Bool {
            guard users[email] != nil else { return false }
            users.removeValue(forKey: email)
            userCount -= 1
            return true
        }
        
        func getAllUsers() -> [User] {
            return Array(users.values).sorted { $0.name < $1.name }
        }
        
        var count: Int {
            return userCount
        }
    }
    
    struct User {
        let id: UUID
        let name: String
        let email: String
        let age: Int
    }
    
    enum UserError: Error {
        case invalidInput
        case userAlreadyExists
    }
    """
    
    @Published var detailDiffLines: [String] = []
    @Published var diffResult: DiffResult?
    
    func generateDiff() {
        do {
            // Ensure both texts end with newline
            var normalizedSource = sourceText
            var normalizedDestination = destinationText
            
            if !normalizedSource.hasSuffix("\n") {
                normalizedSource += "\n"
            }
            
            if !normalizedDestination.hasSuffix("\n") {
                normalizedDestination += "\n"
            }
            
            let diffResult = MultiLineDiff.createDiff(
                source: normalizedSource, 
                destination: normalizedDestination,
                algorithm: .megatron,
                includeMetadata: true
            )
            
            detailDiffLines = DiffProcessor.generateDetailDiffLines(
                from: diffResult, 
                sourceText: normalizedSource
            )
            
            let base64Diff = try MultiLineDiff.createBase64Diff(
                source: normalizedSource, 
                destination: normalizedDestination,
                includeMetadata: true
            )
            print("Base64 Encoded Diff: \(base64Diff)")
            
            let reconstructedText = try MultiLineDiff.applyDiff(
                to: normalizedSource, 
                diff: diffResult
            )
            print("Reconstructed Text Matches: \(reconstructedText == normalizedDestination)")
        } catch {
            print("Diff generation error: \(error)")
            detailDiffLines = ["Error generating diff"]
        }
    }
}

struct DiffOperationView: View {
    let model: DiffOperationModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(model.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(model.numberBackground)
                .clipShape(Circle())
                .padding(4)
            
            HStack(alignment: .center, spacing: 8) {
                Text(model.description)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(model.textColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: 8)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .background(model.background)
    }
}

@available(macOS 11.0, iOS 14.0, *)
struct DiffVisualizationView: View {
    @StateObject private var viewModel = DiffViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 40
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Multi-Line Diff Visualizer")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
                
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Original")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.medium)
                                .frame(width: availableWidth / 2, alignment: .leading)

                            Text("Modified")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.medium)
                                .frame(width: availableWidth / 2, alignment: .leading)
                                .padding(.trailing, 12)
                        }
                        
                        HStack {
                            TextEditor(text: $viewModel.sourceText)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color(white: 0.12))
                                .cornerRadius(8)
                                .padding(.trailing, 12)
                                .disableAutocorrection(true)
                            
                            TextEditor(text: $viewModel.destinationText)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color(white: 0.12))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Diff Operations")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(viewModel.detailDiffLines.enumerated()), id: \.offset) { index, line in
                                    DiffOperationView(
                                        model: DiffOperationModel(
                                            operation: line, 
                                            index: index + 1
                                        )
                                    )
                                }
                            }
                            .background(Color(white: 0.12))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: viewModel.generateDiff) {
                    Text("Generate Diff")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .frame(minHeight: 12)
                }
            }
            .padding(20)
        }
    }
}

@available(macOS 11.0, iOS 14.0, *)
struct ContentView: View {
    var body: some View {
        DiffVisualizationView()
    }
}

@available(macOS 11.0, iOS 14.0, *)
#Preview {
    ContentView()
}

// MARK: - Terminal and ASCII Diff Representations

/// ANSI color codes for terminal output
enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case blue = "\u{001B}[34m"
    case yellow = "\u{001B}[33m"
    case gray = "\u{001B}[90m"
    case bold = "\u{001B}[1m"
    
    // Background colors
    case redBg = "\u{001B}[41m"
    case greenBg = "\u{001B}[42m"
    case blueBg = "\u{001B}[44m"
    case grayBg = "\u{001B}[100m"
}

/// Terminal diff formatter for colored output
public struct TerminalDiffFormatter {
    
    /// Generate ASCII text diff representation (no colors)
    public static func generateASCIIDiff(from diffResult: DiffResult, sourceText: String) -> String {
        let formattedLines = DiffProcessor.generateDetailDiffLines(from: diffResult, sourceText: sourceText)
        return formattedLines.joined(separator: "\n")
    }
    
    /// Generate colored terminal diff representation
    public static func generateColoredTerminalDiff(from diffResult: DiffResult, sourceText: String) -> String {
        let formattedLines = DiffProcessor.generateDetailDiffLines(from: diffResult, sourceText: sourceText)
        var coloredOutput = ""
        
        for line in formattedLines {
            guard let firstChar = line.first else { continue }
            let operation = DiffOperationToText(from: String(firstChar))
            let color = getTerminalColor(for: operation)
            
            // Format: [COLOR][LINE][RESET]
            coloredOutput += "\(color)\(line)\(ANSIColor.reset.rawValue)\n"
        }
        
        return coloredOutput
    }
    
    /// Generate colored terminal diff with background highlighting
    public static func generateHighlightedTerminalDiff(from diffResult: DiffResult, sourceText: String) -> String {
        let formattedLines = DiffProcessor.generateDetailDiffLines(from: diffResult, sourceText: sourceText)
        var highlightedOutput = ""
        
        for line in formattedLines {
            guard let firstChar = line.first else { continue }
            let operation = DiffOperationToText(from: String(firstChar))
            let (textColor, bgColor) = getTerminalHighlightColors(for: operation)
            
            // Format: [BG_COLOR][TEXT_COLOR][LINE][RESET]
            highlightedOutput += "\(bgColor)\(textColor)\(line)\(ANSIColor.reset.rawValue)\n"
        }
        
        return highlightedOutput
    }
    
    /// Generate compact diff summary
    public static func generateCompactDiff(from diffResult: DiffResult) -> String {
        var summary = ""
        var operationCount = [String: Int]()
        
        for operation in diffResult.operations {
            switch operation {
            case .retain(let count):
                operationCount["retained"] = (operationCount["retained"] ?? 0) + count
            case .delete(let count):
                operationCount["deleted"] = (operationCount["deleted"] ?? 0) + count
            case .insert(let text):
                operationCount["inserted"] = (operationCount["inserted"] ?? 0) + text.count
            }
        }
        
        summary += "📊 Diff Summary:\n"
        if let retained = operationCount["retained"] {
            summary += "  \(ANSIColor.blue.rawValue)= \(retained) characters retained\(ANSIColor.reset.rawValue)\n"
        }
        if let deleted = operationCount["deleted"] {
            summary += "  \(ANSIColor.red.rawValue)- \(deleted) characters deleted\(ANSIColor.reset.rawValue)\n"
        }
        if let inserted = operationCount["inserted"] {
            summary += "  \(ANSIColor.green.rawValue)+ \(inserted) characters inserted\(ANSIColor.reset.rawValue)\n"
        }
        
        return summary
    }
    
    // MARK: - Private Helper Methods
    
    private static func getTerminalColor(for operation: DiffOperationToText) -> String {
        switch operation {
        case .retain:
            return ANSIColor.blue.rawValue
        case .delete:
            return ANSIColor.red.rawValue
        case .insert:
            return ANSIColor.green.rawValue
        case .unknown:
            return ANSIColor.gray.rawValue
        }
    }
    
    private static func getTerminalHighlightColors(for operation: DiffOperationToText) -> (text: String, background: String) {
        switch operation {
        case .retain:
            return (ANSIColor.blue.rawValue, ANSIColor.grayBg.rawValue)
        case .delete:
            return (ANSIColor.red.rawValue, ANSIColor.redBg.rawValue)
        case .insert:
            return (ANSIColor.green.rawValue, ANSIColor.greenBg.rawValue)
        case .unknown:
            return (ANSIColor.gray.rawValue, ANSIColor.grayBg.rawValue)
        }
    }
}

/// Convenience extension for MultiLineDiff to generate terminal output
extension MultiLineDiff {
    
    /// Generate ASCII diff representation
    public static func generateASCIIDiff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron
    ) -> String {
        let diffResult = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false
        )
        return TerminalDiffFormatter.generateASCIIDiff(from: diffResult, sourceText: source)
    }
    
    /// Generate colored terminal diff representation
    public static func generateColoredTerminalDiff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron
    ) -> String {
        let diffResult = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false
        )
        return TerminalDiffFormatter.generateColoredTerminalDiff(from: diffResult, sourceText: source)
    }
    
    /// Generate highlighted terminal diff representation
    public static func generateHighlightedTerminalDiff(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron
    ) -> String {
        let diffResult = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false
        )
        return TerminalDiffFormatter.generateHighlightedTerminalDiff(from: diffResult, sourceText: source)
    }
    
    /// Generate compact diff summary
    public static func generateDiffSummary(
        source: String,
        destination: String,
        algorithm: DiffAlgorithm = .megatron
    ) -> String {
        let diffResult = createDiff(
            source: source,
            destination: destination,
            algorithm: algorithm,
            includeMetadata: false
        )
        return TerminalDiffFormatter.generateCompactDiff(from: diffResult)
    }
}
