import XCTest
@testable import Services

final class XPCServiceTests: XCTestCase {
    var xpcService: XPCService!
    
    override func setUp() {
        super.setUp()
        xpcService = XPCService()
    }
    
    override func tearDown() {
        xpcService = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(xpcService.userServiceActive)
        XCTAssertFalse(xpcService.rootServiceActive)
        XCTAssertTrue(xpcService.rootEnabled)
    }
    
    func testRootToggle() {
        let initialState = xpcService.rootEnabled
        xpcService.toggleRootService()
        XCTAssertEqual(xpcService.rootEnabled, !initialState)
    }
    
    func testXPCStatusCheck() {
        let expectation = self.expectation(description: "XPC Status Check")
        
        Task {
            await xpcService.checkXPCStatus()
            // Just verify the method completes without error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
}
