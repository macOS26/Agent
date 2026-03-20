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
    let children: [String: AnyCodable]?
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
        print("No valid input provided")
        writeOutput(outputPath, success: false, data: [:], errors: ["No valid input provided"])
        return 1
    }

    print("WebScrape")
    print("===================================")
    print("URL: \(scrapeInput.url)")

    let result = performScrape(scrapeInput)
    writeOutput(outputPath, output: result)
    return result.success ? 0 : 1
}

func performScrape(_ input: ScrapeInput) -> ScrapeOutput {
    var errors: [String] = []
    var pageCount = 1

    // Connect to Safari
    guard let safari: SafariApplication = SBApplication(bundleIdentifier: "com.apple.Safari") else {
        return ScrapeOutput(success: false, url: input.url, data: [:], pageCount: nil, errors: ["Safari not available"])
    }

    // Activate Safari
    safari.activate()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

    // Open URL
    print("  Opening URL...")
    if let url = URL(string: input.url) {
        _ = safari.open?(url as Any)
    }

    // Wait for initial load
    let waitBefore = input.waitBefore ?? 2.0
    RunLoop.current.run(until: Date(timeIntervalSinceNow: waitBefore))

    // Get front document
    guard let frontDoc = safari.documents?().firstObject as? SafariDocument else {
        return ScrapeOutput(success: false, url: input.url, data: [:], pageCount: nil, errors: ["No Safari document found"])
    }

    // Scroll to load if requested
    if input.scrollToLoad == true {
        print("  Scrolling to load content...")
        let maxScrolls = input.maxScrolls ?? 5
        for i in 1...maxScrolls {
            print("    Scroll \(i)/\(maxScrolls)")
            _ = safari.doJavaScript?("window.scrollBy(0, 1000);", in: frontDoc as Any)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

            _ = safari.doJavaScript?("document.body.scrollHeight", in: frontDoc as Any)
        }

        // Scroll back to top
        _ = safari.doJavaScript?("window.scrollTo(0, 0);", in: frontDoc as Any)
    }

    // Extract data
    print("  Extracting data...")
    var data: [String: Any] = [:]

    for (key, selector) in input.selectors {
        do {
            let extracted = try extractValue(safari: safari, document: frontDoc, selector: selector)
            data[key] = extracted
            print("    OK: \(key)")
        } catch {
            errors.append("Failed to extract \(key): \(error.localizedDescription)")
            print("    WARN: \(key): \(error.localizedDescription)")
        }
    }

    // Handle pagination if configured
    if let pagination = input.pagination,
       let nextSelector = pagination.selector {
        var allData: [[String: Any]] = [data]
        let maxPages = pagination.maxPages ?? 5
        let waitBetween = pagination.waitBetween ?? 2.0

        for page in 2...maxPages {
            print("  Page \(page)")

            // Click next page button
            _ = safari.doJavaScript?("document.querySelector('\(nextSelector)')?.click();", in: frontDoc as Any)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: waitBetween))

            // Check if we're still on a valid page
            if let hasMore = safari.doJavaScript?("document.querySelector('\(nextSelector)') !== null", in: frontDoc as Any) as? String,
               hasMore == "false" {
                break
            }

            // Extract data for this page
            var pageData: [String: Any] = [:]
            for (key, selector) in input.selectors {
                if let extracted = try? extractValue(safari: safari, document: frontDoc, selector: selector) {
                    pageData[key] = extracted
                }
            }
            allData.append(pageData)
            pageCount += 1
        }

        // Combine all pages
        data = ["pages": allData]
    }

    print("Scraping complete")

    return ScrapeOutput(
        success: errors.isEmpty || !data.isEmpty,
        url: input.url,
        data: data,
        pageCount: pageCount,
        errors: errors
    )
}

func runJS(_ safari: SafariApplication, _ js: String, in doc: SafariDocument) -> String? {
    safari.doJavaScript?(js, in: doc as Any) as? String
}

func extractValue(safari: SafariApplication, document: SafariDocument, selector: AnyCodable) throws -> Any {
    if let simpleSelector = selector.value as? String {
        return extractText(safari: safari, document: document, selector: simpleSelector)
    }

    guard let complexSelector = selector.value as? ScrapeSelector else {
        throw ScrapeError.invalidSelector
    }

    return try extractComplex(safari: safari, document: document, selector: complexSelector)
}

func extractText(safari: SafariApplication, document: SafariDocument, selector: String) -> String {
    let js = "document.querySelector('\(selector)')?.textContent?.trim() || ''"
    return runJS(safari, js, in: document) ?? ""
}

func extractComplex(safari: SafariApplication, document: SafariDocument, selector: ScrapeSelector) throws -> Any {
    let escapedSelector = selector.selector
        .replacingOccurrences(of: "'", with: "\\'")

    // Multiple elements
    if selector.multiple == true {
        let countJS = "document.querySelectorAll('\(escapedSelector)').length"
        guard let countStr = runJS(safari, countJS, in: document),
              let count = Int(countStr) else {
            return []
        }

        var results: [[String: Any]] = []

        for i in 0..<count {
            let contextJS = "document.querySelectorAll('\(escapedSelector)')[\(i)]"
            var item: [String: Any] = [:]

            if let children = selector.children {
                for (key, childAnyCodable) in children {
                    if let childSelector = childAnyCodable.value as? ScrapeSelector {
                        let childEscaped = childSelector.selector.replacingOccurrences(of: "'", with: "\\'")
                        if let extracted = try? extractFromContext(
                            safari: safari,
                            document: document,
                            context: "\(contextJS).querySelector('\(childEscaped)')",
                            selector: childSelector
                        ) {
                            item[key] = extracted
                        }
                    } else if let childString = childAnyCodable.value as? String {
                        let childJS = "\(contextJS).querySelector('\(childString.replacingOccurrences(of: "'", with: "\\'"))')?.textContent?.trim() || ''"
                        if let result = runJS(safari, childJS, in: document) {
                            item[key] = result
                        }
                    }
                }
            } else {
                let textJS = "document.querySelectorAll('\(escapedSelector)')[\(i)]?.textContent?.trim() || ''"
                if let text = runJS(safari, textJS, in: document) {
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

        for (key, childAnyCodable) in children {
            if let childSelector = childAnyCodable.value as? ScrapeSelector {
                if let extracted = try? extractFromContext(
                    safari: safari,
                    document: document,
                    context: "document.querySelector('\(escapedSelector)')",
                    selector: childSelector
                ) {
                    result[key] = extracted
                }
            } else if let childString = childAnyCodable.value as? String {
                let childJS = "document.querySelector('\(escapedSelector)')?.querySelector('\(childString.replacingOccurrences(of: "'", with: "\\'"))')?.textContent?.trim() || ''"
                if let text = runJS(safari, childJS, in: document) {
                    result[key] = text
                }
            }
        }

        return result
    }

    // Attribute extraction
    if let attr = selector.attr {
        let js = "document.querySelector('\(escapedSelector)')?.getAttribute('\(attr)') || ''"
        return runJS(safari, js, in: document) ?? ""
    }

    // HTML extraction
    if selector.extractHTML == true {
        let js = "document.querySelector('\(escapedSelector)')?.outerHTML || ''"
        return runJS(safari, js, in: document) ?? ""
    }

    // Default: text content
    return extractText(safari: safari, document: document, selector: selector.selector)
}

func extractFromContext(safari: SafariApplication, document: SafariDocument, context: String, selector: ScrapeSelector) throws -> Any {
    // Attribute
    if let attr = selector.attr {
        let js = "\(context)?.getAttribute('\(attr)') || ''"
        return runJS(safari, js, in: document) ?? ""
    }

    // HTML
    if selector.extractHTML == true {
        let js = "\(context)?.outerHTML || ''"
        return runJS(safari, js, in: document) ?? ""
    }

    // Text
    let textJS = "\(context)?.textContent?.trim() || ''"
    return runJS(safari, textJS, in: document) ?? ""
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

    print("\nOutput saved to: \(path)")
}

func writeOutput(_ path: String, success: Bool, data: [String: Any], errors: [String]) {
    let output = ScrapeOutput(success: success, url: "", data: data, pageCount: nil, errors: errors)
    writeOutput(path, output: output)
}
