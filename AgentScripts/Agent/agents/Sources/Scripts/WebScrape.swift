import Foundation
import SafariBridge

// ============================================================================
// WebScrape - Extract structured data from web pages
//
// USAGE:
//   run_agent_script("WebScrape", args: JSON)
//
// INPUT FORMAT (via AGENT_SCRIPT_ARGS or ~/Documents/AgentScript/json/WebScrape_input.json):
// {
//   "url": "https://example.com/products",
//   "selectors": {
//     "title": "h1.product-title",
//     "price": ".price",
//     "description": ".description",
//     "items": {
//       "selector": ".product-list .item",
//       "multiple": true,
//       "children": {
//         "name": ".name",
//         "price": ".price",
//         "image": { "selector": "img", "attr": "src" }
//       }
//     }
//   },
//   "waitBefore": 2,
//   "scrollToLoad": true,
//   "maxScrolls": 5,
//   "outputFormat": "json"
// }
//
// SELECTOR TYPES:
//   - Simple: "h1.title" - returns text content
//   - Attribute: { "selector": "img", "attr": "src" }
//   - Multiple: { "selector": ".item", "multiple": true }
//   - Nested: { "selector": ".container", "children": { ... } }
//
// OUTPUT: ~/Documents/AgentScript/json/WebScrape_output.json
// ============================================================================

struct ScrapeSelector: Codable {
    let selector: String
    let attr: String?
    let multiple: Bool?
    let children: [String: ScrapeSelector]?
    let extractHTML: Bool?
}

struct ScrapeInput: Codable {
    let url: String
    let selectors: [String: AnyCodable]
    let waitBefore: Double?
    let scrollToLoad: Bool?
    let maxScrolls: Int?
    let outputFormat: String?
    let pagination: PaginationConfig?
}

struct PaginationConfig: Codable {
    let selector: String?
    let maxPages: Int?
    let waitBetween: Double?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let selector = try? container.decode(ScrapeSelector.self) {
            value = selector
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let selector = value as? ScrapeSelector {
            try container.encode(selector)
        } else if let string = value as? String {
            try container.encode(string)
        }
    }
}

struct ScrapeOutput {
    let success: Bool
    let url: String
    let data: [String: Any]
    let pageCount: Int?
    let errors: [String]
}

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/WebScrape_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/WebScrape_output.json"
    
    // Parse input
    var input: ScrapeInput?
    
    if let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"],
       !argsString.isEmpty {
        if let data = argsString.data(using: .utf8) {
            input = try? JSONDecoder().decode(ScrapeInput.self, from: data)
        }
    }
    
    if input == nil,
       let data = FileManager.default.contents(atPath: inputPath) {
        input = try? JSONDecoder().decode(ScrapeInput.self, from: data)
    }
    
    guard let scrapeInput = input else {
        print("❌ No valid input provided")
        writeOutput(outputPath, success: false, data: [:], errors: ["No valid input provided"])
        return 1
    }
    
    print("🕷️ WebScrape")
    print("═══════════════════════════════════")
    print("URL: \(scrapeInput.url)")
    
    // Run scraping
    let semaphore = DispatchSemaphore(value: 0)
    var result: ScrapeOutput?
    
    Task { @MainActor in
        result = await performScrape(scrapeInput)
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
func performScrape(_ input: ScrapeInput) async -> ScrapeOutput {
    var errors: [String] = []
    var pageCount = 1
    
    // Connect to Safari
    guard let safari: SBApplication<SAApplication> = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        return ScrapeOutput(success: false, url: input.url, data: [:], pageCount: nil, errors: ["Safari not available"])
    }
    
    // Activate Safari
    safari.activate()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    
    // Open URL
    print("  📖 Opening URL...")
    let url = URL(string: input.url)!
    safari.open(url)
    
    // Wait for initial load
    let waitBefore = input.waitBefore ?? 2.0
    RunLoop.current.run(until: Date(timeIntervalSinceNow: waitBefore))
    
    // Get front document
    guard let frontDoc = safari.documents?().firstObject as? SADocument else {
        return ScrapeOutput(success: false, url: input.url, data: [:], pageCount: nil, errors: ["No Safari document found"])
    }
    
    // Scroll to load if requested
    if input.scrollToLoad == true {
        print("  📜 Scrolling to load content...")
        let maxScrolls = input.maxScrolls ?? 5
        for i in 1...maxScrolls {
            print("    Scroll \(i)/\(maxScrolls)")
            let scrollJS = "window.scrollBy(0, 1000);"
            _ = frontDoc.doJavaScript?(scrollJS) as String?
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
            
            // Check if more content loaded
            let heightJS = "document.body.scrollHeight"
            if let _ = frontDoc.doJavaScript?(heightJS) as? String {
                // Continue scrolling
            }
        }
        
        // Scroll back to top
        _ = frontDoc.doJavaScript?("window.scrollTo(0, 0);") as String?
    }
    
    // Extract data
    print("  🔍 Extracting data...")
    var data: [String: Any] = [:]
    
    for (key, selector) in input.selectors {
        do {
            let extracted = try extractValue(document: frontDoc, selector: selector)
            data[key] = extracted
            print("    ✅ \(key)")
        } catch {
            errors.append("Failed to extract \(key): \(error.localizedDescription)")
            print("    ⚠️ \(key): \(error.localizedDescription)")
        }
    }
    
    // Handle pagination if configured
    if let pagination = input.pagination,
       let nextSelector = pagination.selector {
        var allData: [[String: Any]] = [data]
        let maxPages = pagination.maxPages ?? 5
        let waitBetween = pagination.waitBetween ?? 2.0
        
        for page in 2...maxPages {
            print("  📄 Page \(page)")
            
            // Click next page button
            let clickJS = "document.querySelector('\(nextSelector)')?.click();"
            _ = frontDoc.doJavaScript?(clickJS) as String?
            RunLoop.current.run(until: Date(timeIntervalSinceNow: waitBetween))
            
            // Check if we're still on a valid page
            let nextButtonCheck = "document.querySelector('\(nextSelector)') !== null"
            if let hasMore = frontDoc.doJavaScript?(nextButtonCheck) as? String,
               hasMore == "false" {
                break
            }
            
            // Extract data for this page
            var pageData: [String: Any] = [:]
            for (key, selector) in input.selectors {
                if let extracted = try? extractValue(document: frontDoc, selector: selector) {
                    pageData[key] = extracted
                }
            }
            allData.append(pageData)
            pageCount += 1
        }
        
        // Combine all pages
        data = ["pages": allData]
    }
    
    print("✅ Scraping complete")
    
    return ScrapeOutput(
        success: errors.isEmpty || !data.isEmpty,
        url: input.url,
        data: data,
        pageCount: pageCount,
        errors: errors
    )
}

@MainActor
func extractValue(document: SADocument, selector: AnyCodable) throws -> Any {
    // Handle simple string selector
    if let simpleSelector = selector.value as? String {
        return try extractText(document: document, selector: simpleSelector)
    }
    
    // Handle complex selector
    guard let complexSelector = selector.value as? ScrapeSelector else {
        throw ScrapeError.invalidSelector
    }
    
    return try extractComplex(document: document, selector: complexSelector)
}

@MainActor
func extractText(document: SADocument, selector: String) throws -> String {
    let js = "document.querySelector('\(selector)')?.textContent?.trim() || ''"
    if let result = document.doJavaScript?(js) as? String {
        return result
    }
    return ""
}

@MainActor
func extractComplex(document: SADocument, selector: ScrapeSelector) throws -> Any {
    let escapedSelector = selector.selector
        .replacingOccurrences(of: "'", with: "\\'")
    
    // Multiple elements
    if selector.multiple == true {
        let countJS = "document.querySelectorAll('\(escapedSelector)').length"
        guard let countStr = document.doJavaScript?(countJS) as? String,
              let count = Int(countStr) else {
            return []
        }
        
        var results: [[String: Any]] = []
        
        for i in 0..<count {
            // Get this element's context
            let contextJS = "document.querySelectorAll('\(escapedSelector)')[\(i)]"
            
            var item: [String: Any] = [:]
            
            // Extract children if defined
            if let children = selector.children {
                for (key, childSelector) in children {
                    if let childValue = childSelector.value as? ScrapeSelector {
                        if let extracted = try? extractFromContext(
                            document: document,
                            context: "\(contextJS).querySelector('\(childSelector.selector.replacingOccurrences(of: "'", with: "\\'"))')",
                            selector: childValue
                        ) {
                            item[key] = extracted
                        }
                    } else if let childString = childSelector.value as? String {
                        let childJS = "\(contextJS).querySelector('\(childString.replacingOccurrences(of: "'", with: "\\'"))')?.textContent?.trim() || ''"
                        if let result = document.doJavaScript?(childJS) as? String {
                            item[key] = result
                        }
                    }
                }
            } else {
                // Just get text content
                let textJS = "document.querySelectorAll('\(escapedSelector)')[\(i)]?.textContent?.trim() || ''"
                if let text = document.doJavaScript?(textJS) as? String {
                    item = ["text": text]
                }
            }
            
            results.append(item)
        }
        
        return results
    }
    
    // Single element with children
    if let children = selector.children {
        var result: [String: Any] = [:]
        
        for (key, childSelector) in children {
            if let childValue = childSelector.value as? ScrapeSelector {
                if let extracted = try? extractFromContext(
                    document: document,
                    context: "document.querySelector('\(escapedSelector)')",
                    selector: childValue
                ) {
                    result[key] = extracted
                }
            } else if let childString = childSelector.value as? String {
                let childJS = "document.querySelector('\(escapedSelector)')?.querySelector('\(childString.replacingOccurrences(of: "'", with: "\\'"))')?.textContent?.trim() || ''"
                if let text = document.doJavaScript?(childJS) as? String {
                    result[key] = text
                }
            }
        }
        
        return result
    }
    
    // Attribute extraction
    if let attr = selector.attr {
        let js = "document.querySelector('\(escapedSelector)')?.getAttribute('\(attr)') || ''"
        if let result = document.doJavaScript?(js) as? String {
            return result
        }
        return ""
    }
    
    // HTML extraction
    if selector.extractHTML == true {
        let js = "document.querySelector('\(escapedSelector)')?.outerHTML || ''"
        if let result = document.doJavaScript?(js) as? String {
            return result
        }
        return ""
    }
    
    // Default: text content
    return try extractText(document: document, selector: selector.selector)
}

@MainActor
func extractFromContext(document: SADocument, context: String, selector: ScrapeSelector) throws -> Any {
    let escapedSelector = selector.selector.replacingOccurrences(of: "'", with: "\\'")
    
    // Attribute
    if let attr = selector.attr {
        let js = "\(context)?.getAttribute('\(attr)') || ''"
        if let result = document.doJavaScript?(js) as? String {
            return result
        }
        return ""
    }
    
    // HTML
    if selector.extractHTML == true {
        let js = "\(context)?.outerHTML || ''"
        if let result = document.doJavaScript?(js) as? String {
            return result
        }
        return ""
    }
    
    // Text
    let textJS = "\(context)?.textContent?.trim() || ''"
    if let text = document.doJavaScript?(textJS) as? String {
        return text
    }
    
    return ""
}

enum ScrapeError: Error {
    case invalidSelector
    case elementNotFound
}

func writeOutput(_ path: String, output: ScrapeOutput) {
    var dict: [String: Any] = [
        "success": output.success,
        "url": output.url,
        "errors": output.errors
    ]
    
    if let pageCount = output.pageCount {
        dict["pageCount"] = pageCount
    }
    
    dict["data"] = output.data
    
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? data.write(to: URL(fileURLWithPath: path))
    
    print("\n📄 Output saved to: \(path)")
}

func writeOutput(_ path: String, success: Bool, data: [String: Any], errors: [String]) {
    let output = ScrapeOutput(success: success, url: "", data: data, pageCount: nil, errors: errors)
    writeOutput(path, output: output)
}