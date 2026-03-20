import Foundation
import SafariBridge

// ============================================================================
// WebForm - Fill web forms automatically using Safari ScriptingBridge
//
// USAGE:
//   run_agent_script("WebForm", args: JSON)
//
// INPUT FORMAT (via AGENT_SCRIPT_ARGS or ~/Documents/AgentScript/json/WebForm_input.json):
// {
//   "url": "https://example.com/form",
//   "fields": [
//     { "selector": "#email", "value": "user@example.com" },
//     { "selector": "#password", "value": "secret123" },
//     { "selector": "#remember", "type": "checkbox", "action": "check" },
//     { "selector": "#country", "type": "select", "value": "US" }
//   ],
//   "submit": "#submit-button",
//   "waitForSuccess": "Thank you",
//   "timeout": 30
// }
//
// SELECTOR TYPES:
//   - CSS selector: "#email", ".password-field", "input[name='email']"
//   - XPath: "//input[@type='email']"
//   - Accessibility: "AXTextField", "AXButton"
//
// FIELD TYPES:
//   - text (default): Type text into input field
//   - checkbox: Check/uncheck
//   - radio: Select radio button
//   - select: Select dropdown option
//   - textarea: Multi-line text input
//
// OUTPUT: ~/Documents/AgentScript/json/WebForm_output.json
// ============================================================================

struct FormField: Codable {
    let selector: String
    let value: String?
    let type: String?
    let action: String?
    let strategy: String?
    let index: Int?
}

struct FormInput: Codable {
    let url: String?
    let fields: [FormField]
    let submit: String?
    let waitForSuccess: String?
    let timeout: Double?
    let verifyFields: Bool?
    let delayBetweenFields: Double?
}

struct FormOutput: Codable {
    let success: Bool
    let url: String
    let filledFields: Int
    let errors: [String]
    let finalUrl: String?
    let pageTitle: String?
}

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/WebForm_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/WebForm_output.json"
    
    // Parse input
    var input: FormInput?
    
    // Try AGENT_SCRIPT_ARGS first
    if let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"],
       !argsString.isEmpty {
        if let data = argsString.data(using: .utf8) {
            input = try? JSONDecoder().decode(FormInput.self, from: data)
        }
    }
    
    // Try JSON file
    if input == nil,
       let data = FileManager.default.contents(atPath: inputPath) {
        input = try? JSONDecoder().decode(FormInput.self, from: data)
    }
    
    guard let formInput = input else {
        print("❌ No valid input provided")
        writeOutput(outputPath, success: false, errors: ["No valid input provided"])
        return 1
    }
    
    print("📝 WebForm Automation")
    print("═══════════════════════════════════")
    print("Fields to fill: \(formInput.fields.count)")
    
    // Run form filling
    let semaphore = DispatchSemaphore(value: 0)
    var result: FormOutput?
    
    Task { @MainActor in
        result = await fillForm(formInput)
        semaphore.signal()
    }
    
    semaphore.wait()
    
    // Write output
    if let output = result {
        writeOutput(outputPath, output: output)
        return output.success ? 0 : 1
    }
    
    return 1
}

@MainActor
func fillForm(_ input: FormInput) async -> FormOutput {
    var errors: [String] = []
    var filledCount = 0
    let timeout = input.timeout ?? 30.0
    let delayBetweenFields = input.delayBetweenFields ?? 0.1
    let verifyFields = input.verifyFields ?? true
    
    // Connect to Safari
    guard let safari: SBApplication<SAApplication> = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        return FormOutput(success: false, url: input.url ?? "", filledFields: 0, errors: ["Safari not available"], finalUrl: nil, pageTitle: nil)
    }
    
    // Open URL if provided
    if let urlString = input.url {
        print("🌐 Opening URL: \(urlString)")
        let url = URL(string: urlString)!
        
        // Activate Safari
        safari.activate()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Open URL
        safari.open(url)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }
    
    // Get front document
    guard let frontDoc = safari.documents?().firstObject as? SADocument else {
        return FormOutput(success: false, url: input.url ?? "", filledFields: 0, errors: ["No Safari document found"], finalUrl: nil, pageTitle: nil)
    }
    
    // Fill each field
    for (index, field) in input.fields.enumerated() {
        print("  [\(index + 1)/\(input.fields.count)] Filling: \(field.selector)")
        
        let success = await fillField(safari: safari, document: frontDoc, field: field, verify: verifyFields)
        
        if success {
            filledCount += 1
        } else {
            errors.append("Failed to fill field: \(field.selector)")
        }
        
        // Delay between fields
        if delayBetweenFields > 0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: delayBetweenFields))
        }
    }
    
    // Get final URL and title
    var finalUrl: String?
    var pageTitle: String?
    
    if let url = frontDoc.url {
        finalUrl = url
    }
    
    if let name = frontDoc.name {
        pageTitle = name
    }
    
    // Submit form if specified
    if let submitSelector = input.submit {
        print("  🖱️ Clicking submit: \(submitSelector)")
        
        // Use JavaScript to click submit button
        let js = "document.querySelector('\(submitSelector)')?.click();"
        _ = frontDoc.doJavaScript?(js) as String?
        
        // Wait for success message if specified
        if let waitForSuccess = input.waitForSuccess {
            print("  ⏳ Waiting for success: \(waitForSuccess)")
            let startTime = Date()
            var found = false
            
            while Date().timeIntervalSince(startTime) < timeout {
                let checkJS = "document.body.innerText.contains('\(waitForSuccess)')"
                if let result = frontDoc.doJavaScript?(checkJS) as? String,
                   result == "true" {
                    found = true
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            if !found {
                errors.append("Success message not found: \(waitForSuccess)")
            }
        } else {
            // Wait for page load
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    let success = errors.isEmpty || filledCount > 0
    print("✅ Filled \(filledCount)/\(input.fields.count) fields")
    
    return FormOutput(
        success: success,
        url: input.url ?? "",
        filledFields: filledCount,
        errors: errors,
        finalUrl: finalUrl,
        pageTitle: pageTitle
    )
}

@MainActor
func fillField(safari: SBApplication<SAApplication>, document: SADocument, field: FormField, verify: Bool) async -> Bool {
    let selector = field.selector
    let value = field.value ?? ""
    let fieldType = field.type ?? "text"
    let strategy = field.strategy ?? "css"
    
    // Escape selector for JavaScript
    let escapedSelector = selector
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
    let escapedValue = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
    
    var js: String
    
    switch fieldType {
    case "text", "textarea":
        // Find element and set value
        js = """
        (function() {
            var el = document.querySelector('\(escapedSelector)');
            if (!el) return 'not found';
            el.value = '\(escapedValue)';
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return 'filled';
        })()
        """
        
    case "checkbox":
        let shouldCheck = field.action == "check"
        js = """
        (function() {
            var el = document.querySelector('\(escapedSelector)');
            if (!el) return 'not found';
            el.checked = \(shouldCheck);
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return '\(shouldCheck ? "checked" : "unchecked")';
        })()
        """
        
    case "radio":
        js = """
        (function() {
            var radios = document.querySelectorAll('\(escapedSelector)');
            for (var i = 0; i < radios.length; i++) {
                radios[i].checked = true;
                radios[i].dispatchEvent(new Event('change', { bubbles: true }));
                return 'selected';
            }
            return 'not found';
        })()
        """
        
    case "select":
        js = """
        (function() {
            var el = document.querySelector('\(escapedSelector)');
            if (!el) return 'not found';
            el.value = '\(escapedValue)';
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return 'selected';
        })()
        """
        
    default:
        // Default: set value
        js = "document.querySelector('\(escapedSelector)').value = '\(escapedValue)'; 'filled';"
    }
    
    // Execute JavaScript
    let result = document.doJavaScript?(js) as? String
    
    if result == "not found" {
        print("    ⚠️ Element not found: \(selector)")
        return false
    }
    
    // Verify if requested
    if verify && fieldType == "text" {
        let verifyJS = "document.querySelector('\(escapedSelector)')?.value"
        if let actualValue = document.doJavaScript?(verifyJS) as? String,
           actualValue != value {
            print("    ⚠️ Verification failed: expected '\(value)', got '\(actualValue)'")
            // Try again with focus and type
            return false
        }
    }
    
    print("    ✅ Filled: \(selector)")
    return true
}

func writeOutput(_ path: String, output: FormOutput) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    guard let data = try? encoder.encode(output) else { return }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? data.write(to: URL(fileURLWithPath: path))
    
    print("\n📄 Output saved to: \(path)")
}