@_exported import ScriptingBridgeCommon

// MARK: WishGenericMethods
@objc public protocol WishGenericMethods {
    @objc optional func print() // Print a document.
}

// MARK: WishApplication
@objc public protocol WishApplication: SBApplicationProtocol {
    @objc optional func `open`(_ x: Any!) // Open a document.
    @objc optional func print(_ x: Any!) // Print a document.
    @objc optional func quit() // Quit the application.
    @objc optional func doScript(_ x: String!) -> String // Execute a Tcl script.
}
extension SBApplication: WishApplication {}
