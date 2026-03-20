@_exported import ScriptingBridgeCommon

// MARK: AppleScriptUtilityApplicationScriptsPositions
@objc public enum AppleScriptUtilityApplicationScriptsPositions : AEKeyword {
    case top = 0x746f7020 /* top */
    case bottom = 0x6274746d /* bottom */
}

// MARK: AppleScriptUtilityApplication
@objc public protocol AppleScriptUtilityApplication: SBApplicationProtocol {
    @objc optional var defaultScriptEditor: URL { get } // the editor to be used to open scripts
    @objc optional var GUIScriptingEnabled: Bool { get } // Are GUI Scripting events currently being processed?
    @objc optional var applicationScriptsPosition: AppleScriptUtilityApplicationScriptsPositions { get } // the position in the Script menu at which the application scripts are displayed
    @objc optional var ScriptMenuEnabled: Bool { get } // Is the Script menu installed in the menu bar?
    @objc optional var showComputerScripts: Bool { get } // Are the Computer scripts shown in the Script menu?
}
extension SBApplication: AppleScriptUtilityApplication {}
