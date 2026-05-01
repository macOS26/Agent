import Testing
import Foundation
@testable import Agent_

/// Unit tests for the Exa search provider helpers in WebSearch.swift.
/// These tests cover response parsing and snippet fallback. They never
/// hit the network — `formatExaResponse` is deliberately exposed so we
/// can feed in hardcoded fixtures.
@Suite("ExaSearch")
@MainActor struct ExaSearchTests {

    // MARK: - formatExaResponse

    @Test("Parses standard Exa response with text + highlights")
    func parsesStandardResponse() throws {
        let json = #"""
        {
          "results": [
            {
              "title": "Neural Search Explained",
              "url": "https://example.com/neural",
              "publishedDate": "2025-01-15T00:00:00.000Z",
              "author": "Jane Doe",
              "text": "Neural search uses embedding models to retrieve semantically relevant pages.",
              "highlights": ["Neural search uses embeddings to retrieve relevant pages."]
            }
          ]
        }
        """#
        let data = Data(json.utf8)
        let out = AgentViewModel.formatExaResponse(data: data, query: "neural search")
        #expect(out.contains("1. Neural Search Explained"))
        #expect(out.contains("https://example.com/neural"))
        #expect(out.contains("Jane Doe"))
        #expect(out.contains("2025-01-15"))
        #expect(out.contains("Neural search uses embeddings"))
    }

    @Test("Empty results array returns no-results message")
    func emptyResults() {
        let json = #"{ "results": [] }"#
        let out = AgentViewModel.formatExaResponse(data: Data(json.utf8), query: "obscure query")
        #expect(out.contains("No search results found for 'obscure query'"))
    }

    @Test("Malformed JSON returns parse error")
    func malformedJSON() {
        let out = AgentViewModel.formatExaResponse(data: Data("not json".utf8), query: "x")
        #expect(out.hasPrefix("Error: Failed to parse Exa response"))
    }

    @Test("Missing optional fields render gracefully")
    func missingOptionalFields() {
        let json = #"""
        { "results": [ { "url": "https://example.com/x" } ] }
        """#
        let out = AgentViewModel.formatExaResponse(data: Data(json.utf8), query: "x")
        #expect(out.contains("1. Untitled"))
        #expect(out.contains("https://example.com/x"))
        // No author/date metadata line
        #expect(!out.contains("[ · ]"))
    }

    // MARK: - Snippet fallback (highlights → summary → text)

    @Test("Snippet prefers highlights when present")
    func snippetPrefersHighlights() {
        let snippet = AgentViewModel.exaSnippet(
            highlights: ["First highlight.", "Second highlight."],
            summary: "Summary text.",
            text: "Full text content."
        )
        #expect(snippet == "First highlight. … Second highlight.")
    }

    @Test("Snippet falls back to summary when highlights empty")
    func snippetFallsBackToSummary() {
        let snippet = AgentViewModel.exaSnippet(
            highlights: [],
            summary: "Summary text.",
            text: "Full text content."
        )
        #expect(snippet == "Summary text.")
    }

    @Test("Snippet falls back to text when highlights and summary missing")
    func snippetFallsBackToText() {
        let snippet = AgentViewModel.exaSnippet(
            highlights: nil,
            summary: nil,
            text: "Full text content."
        )
        #expect(snippet == "Full text content.")
    }

    @Test("Snippet returns empty string when nothing populated")
    func snippetEmpty() {
        let snippet = AgentViewModel.exaSnippet(highlights: nil, summary: "   ", text: "")
        #expect(snippet == "")
    }

    @Test("Snippet skips whitespace-only highlights")
    func snippetSkipsWhitespaceHighlights() {
        let snippet = AgentViewModel.exaSnippet(
            highlights: ["   ", ""],
            summary: "Summary text.",
            text: nil
        )
        #expect(snippet == "Summary text.")
    }

    // MARK: - Disabled state

    @Test("Empty API key returns 'not set' error without making a request")
    func emptyAPIKey() async {
        let result = await AgentViewModel.performExaSearchInternal(query: "test", apiKey: "")
        #expect(result == "Error: Exa API key not set. Add it in Settings.")
    }
}
