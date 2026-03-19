import XCTest
@testable import MCPClient

final class HTTPConnectionTests: XCTestCase {

    // MARK: - SSEParser Unit Tests

    func testSSEParserBasicMessageEvent() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("event: message"))
        XCTAssertNil(parser.processLine("data: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}"))
        let result = parser.processLine("")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["id"] as? Int, 1)
        XCTAssertNotNil(result?["result"])
    }

    func testSSEParserDefaultEventType() {
        // No "event:" line → default type, should still be parsed
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("data: {\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"tools\":[]}}"))
        let result = parser.processLine("")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["id"] as? Int, 2)
    }

    func testSSEParserIgnoresNonMessageEvents() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("event: endpoint"))
        XCTAssertNil(parser.processLine("data: /some/endpoint"))
        let result = parser.processLine("")
        XCTAssertNil(result)
    }

    func testSSEParserIgnoresComments() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine(": this is a keepalive comment"))
        XCTAssertNil(parser.processLine("data: {\"id\":1,\"result\":{}}"))
        let result = parser.processLine("")
        XCTAssertNotNil(result)
    }

    func testSSEParserIgnoresIdAndRetry() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("id: evt-123"))
        XCTAssertNil(parser.processLine("retry: 5000"))
        XCTAssertNil(parser.processLine("data: {\"id\":1,\"result\":{}}"))
        let result = parser.processLine("")
        XCTAssertNotNil(result)
    }

    func testSSEParserFlushWithoutTrailingBlankLine() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("event: message"))
        XCTAssertNil(parser.processLine("data: {\"id\":3,\"result\":{}}"))
        // Stream closes without blank line
        let result = parser.flush()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["id"] as? Int, 3)
    }

    func testSSEParserFlushClearsState() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("data: {\"id\":1,\"result\":{}}"))
        _ = parser.flush()
        // Second flush should return nil (state cleared)
        let result = parser.flush()
        XCTAssertNil(result)
    }

    func testSSEParserMultipleEvents() {
        var parser = SSEParser()
        var results: [[String: Any]] = []

        // First event: notification (no id)
        XCTAssertNil(parser.processLine("event: message"))
        XCTAssertNil(parser.processLine("data: {\"jsonrpc\":\"2.0\",\"method\":\"notifications/progress\"}"))
        if let r = parser.processLine("") { results.append(r) }

        // Second event: response
        XCTAssertNil(parser.processLine("event: message"))
        XCTAssertNil(parser.processLine("data: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"done\":true}}"))
        if let r = parser.processLine("") { results.append(r) }

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["method"] as? String, "notifications/progress")
        XCTAssertEqual(results[1]["id"] as? Int, 1)
    }

    func testSSEParserInvalidJSON() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("data: not-valid-json"))
        let result = parser.processLine("")
        XCTAssertNil(result)
    }

    func testSSEParserEmptyData() {
        var parser = SSEParser()
        XCTAssertNil(parser.processLine("data: "))
        let result = parser.processLine("")
        XCTAssertNil(result)
    }

    // MARK: - HTTPConnection.parseSSEData Tests

    func testParseSSEDataBasic() throws {
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"tools\":[]}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1)
        XCTAssertEqual(result["id"] as? Int, 1)
        let res = result["result"] as? [String: Any]
        XCTAssertNotNil(res?["tools"])
    }

    func testParseSSEDataWithNotificationsBeforeResponse() throws {
        let sse = """
        event: message
        data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":50}}

        event: message
        data: {"jsonrpc":"2.0","id":5,"result":{"content":[{"type":"text","text":"Hello"}]}}

        """
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 5)
        XCTAssertEqual(result["id"] as? Int, 5)
    }

    func testParseSSEDataWithStringId() throws {
        let sse = "data: {\"jsonrpc\":\"2.0\",\"id\":\"7\",\"result\":{}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 7)
        XCTAssertEqual(result["id"] as? String, "7")
    }

    func testParseSSEDataFallbackToLastJSON() throws {
        // No exact ID match — falls back to last JSON
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":99,\"result\":{\"fallback\":true}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1)
        XCTAssertEqual(result["id"] as? Int, 99)
    }

    func testParseSSEDataEmptyThrows() {
        let data = "".data(using: .utf8)!
        XCTAssertThrowsError(try HTTPConnection.parseSSEData(data, expectedId: 1)) { error in
            XCTAssertTrue(error is MCPClientError)
        }
    }

    func testParseSSEDataNoValidJSONThrows() {
        let sse = "data: not-json-at-all\n\n"
        XCTAssertThrowsError(try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1))
    }

    func testParseSSEDataWithoutTrailingNewline() throws {
        let sse = "event: message\ndata: {\"id\":1,\"result\":{}}"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1)
        XCTAssertEqual(result["id"] as? Int, 1)
    }

    func testParseSSEDataIgnoresEndpointEvent() throws {
        // Old SSE transport sends an "endpoint" event first — must be ignored
        let sse = "event: endpoint\ndata: /messages?sessionId=abc123\n\nevent: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"serverInfo\":{\"name\":\"test\"}}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1)
        XCTAssertEqual(result["id"] as? Int, 1)
        let res = result["result"] as? [String: Any]
        let info = res?["serverInfo"] as? [String: Any]
        XCTAssertEqual(info?["name"] as? String, "test")
    }

    // MARK: - matchesId Tests

    func testMatchesIdInt() {
        let json: [String: Any] = ["id": 42, "result": [String: Any]()]
        XCTAssertTrue(HTTPConnection.matchesId(json, expectedId: 42))
        XCTAssertFalse(HTTPConnection.matchesId(json, expectedId: 1))
    }

    func testMatchesIdString() {
        let json: [String: Any] = ["id": "42", "result": [String: Any]()]
        XCTAssertTrue(HTTPConnection.matchesId(json, expectedId: 42))
        XCTAssertFalse(HTTPConnection.matchesId(json, expectedId: 1))
    }

    func testMatchesIdMissing() {
        let json: [String: Any] = ["method": "notification"]
        XCTAssertFalse(HTTPConnection.matchesId(json, expectedId: 1))
    }

    // MARK: - HTTPConnection Lifecycle Tests

    func testHTTPConnectionInitiallyAlive() {
        let conn = HTTPConnection(url: URL(string: "https://example.com/mcp")!, headers: [:])
        XCTAssertTrue(conn.isAlive)
    }

    func testHTTPConnectionDisconnect() {
        let conn = HTTPConnection(url: URL(string: "https://example.com/mcp")!, headers: [:])
        conn.disconnect()
        XCTAssertFalse(conn.isAlive)
    }

    func testHTTPConnectionSendAfterDisconnect() async {
        let conn = HTTPConnection(url: URL(string: "https://example.com/mcp")!, headers: [:])
        conn.disconnect()
        do {
            _ = try await conn.sendRequest(method: "test", params: nil)
            XCTFail("Should throw")
        } catch let error as MCPClientError {
            if case .connectionFailed(let msg) = error {
                XCTAssertTrue(msg.contains("closed"))
            } else { XCTFail("Wrong error: \(error)") }
        } catch { XCTFail("Unexpected: \(error)") }
    }

    // MARK: - MCP Spec Compliance: SSE JSON Format

    func testMCPInitializeResponseSSE() throws {
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"example-server\",\"version\":\"1.0.0\"}}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 1)
        let res = result["result"] as? [String: Any]
        XCTAssertEqual(res?["protocolVersion"] as? String, "2024-11-05")
        let info = res?["serverInfo"] as? [String: Any]
        XCTAssertEqual(info?["name"] as? String, "example-server")
        XCTAssertNotNil((res?["capabilities"] as? [String: Any])?["tools"])
    }

    func testMCPToolsListResponseSSE() throws {
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"tools\":[{\"name\":\"read_file\",\"description\":\"Read a file\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}},\"required\":[\"path\"]}}]}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 2)
        let res = result["result"] as? [String: Any]
        let tools = res?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
        XCTAssertEqual(tools?.first?["name"] as? String, "read_file")
    }

    func testMCPToolCallResponseSSE() throws {
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"File contents here\"}],\"isError\":false}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 3)
        let res = result["result"] as? [String: Any]
        XCTAssertEqual(res?["isError"] as? Bool, false)
        let content = res?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, "File contents here")
    }

    func testMCPErrorResponseSSE() throws {
        let sse = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":4,\"error\":{\"code\":-32600,\"message\":\"Invalid request\"}}\n\n"
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 4)
        let err = result["error"] as? [String: Any]
        XCTAssertEqual(err?["code"] as? Int, -32600)
        XCTAssertEqual(err?["message"] as? String, "Invalid request")
    }

    func testMCPProgressThenResponseSSE() throws {
        // Server sends progress notifications before the tool result
        let sse = """
        event: message
        data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":"tok1","progress":25,"total":100}}

        event: message
        data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":"tok1","progress":75,"total":100}}

        event: message
        data: {"jsonrpc":"2.0","id":10,"result":{"content":[{"type":"text","text":"Done"}],"isError":false}}

        """
        let result = try HTTPConnection.parseSSEData(sse.data(using: .utf8)!, expectedId: 10)
        XCTAssertEqual(result["id"] as? Int, 10)
        let res = result["result"] as? [String: Any]
        let content = res?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, "Done")
    }
}
