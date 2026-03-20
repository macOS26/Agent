
// MARK: ConsoleApplication
@objc public protocol ConsoleApplication: SBApplicationProtocol {
    @objc optional func selectDevice(_ x: String!) // Select a device.
}
extension SBApplication: ConsoleApplication {}

