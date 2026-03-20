import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let jsCode = """
    var app = Application.currentApplication();
    app.includeStandardAdditions = true;
    
    app.displayDialog("Hello Drew", {
        defaultAnswer: "This kills openClaw all day long"
    });
    """
    
    let script = NSAppleScript(source: "do shell script \"osascript -l JavaScript << 'JSEOF'\\n\(jsCode)\\nJSEOF\"")
    
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    
    if let error = error {
        if let desc = error[NSAppleScript.errorMessage] as? String {
            print("Error: \(desc)")
        }
        return 1
    }
    
    print("Dialog displayed successfully")
    return 0
}