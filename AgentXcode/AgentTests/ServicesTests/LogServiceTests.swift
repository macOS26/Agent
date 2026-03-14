import XCTest
@testable import Services

final class LogServiceTests: XCTestCase {
    var logService: LogService!
    
    override func setUp() {
        super.setUp()
        logService = LogService()
        logService.clearLog()
    }
    
    override func tearDown() {
        logService.clearLog()
        logService = nil
        super.tearDown()
    }
    
    func testLogInitialization() {
        XCTAssertEqual(logService.activityLog, "")
    }
    
    func testLogAppend() {
        logService.appendStreamDelta("Test message")
        logService.persistLogNow()
        XCTAssertTrue(logService.activityLog.contains("Test message"))
    }
    
    func testLogClear() {
        logService.appendStreamDelta("Test message")
        logService.persistLogNow()
        logService.clearLog()
        XCTAssertEqual(logService.activityLog, "")
    }
    
    func testLogPersistence() {
        let testMessage = "Persistence test"
        logService.appendStreamDelta(testMessage)
        logService.persistLogNow()
        
        // Create new instance to test persistence
        let newLogService = LogService()
        XCTAssertTrue(newLogService.activityLog.contains(testMessage))
    }
}
