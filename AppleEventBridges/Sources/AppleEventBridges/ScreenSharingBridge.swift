
// MARK: ScreenSharingApplication
@objc public protocol ScreenSharingApplication: SBApplicationProtocol {
    @objc optional func GetURL(_ x: String!) // Open a vnc URL
}
extension SBApplication: ScreenSharingApplication {}

