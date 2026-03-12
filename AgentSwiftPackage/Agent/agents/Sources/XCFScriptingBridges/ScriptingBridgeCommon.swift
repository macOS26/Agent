@_exported import AppKit
@_exported import ScriptingBridge
@_exported import Foundation

@objc public protocol SBObjectProtocol: NSObjectProtocol {
    func get() -> Any!
}

@objc public protocol SBApplicationProtocol: SBObjectProtocol {
    func activate()
    var delegate: SBApplicationDelegate! { get set }
    var isRunning: Bool { get }
}

// AEKeyword type used by AppleScript enums
public typealias AEKeyword = FourCharCode
public typealias FourCharCode = UInt32
