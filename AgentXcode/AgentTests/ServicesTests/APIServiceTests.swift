import XCTest
@testable import Services

final class APIServiceTests: XCTestCase {
    var apiService: APIService!
    
    override func setUp() {
        super.setUp()
        apiService = APIService()
    }
    
    override func tearDown() {
        apiService = nil
        super.tearDown()
    }
    
    func testInitialProvider() {
        XCTAssertEqual(apiService.selectedProvider, .claude)
    }
    
    func testDefaultClaudeModels() {
        XCTAssertFalse(apiService.claudeModels.isEmpty)
        XCTAssertTrue(apiService.claudeModels.count >= 9)
    }
    
    func testDefaultOllamaModels() {
        XCTAssertFalse(apiService.ollamaModels.isEmpty)
        XCTAssertTrue(apiService.ollamaModels.count >= 20)
    }
    
    func testProviderChange() {
        apiService.selectedProvider = .ollama
        XCTAssertEqual(apiService.selectedProvider, .ollama)
    }
}
