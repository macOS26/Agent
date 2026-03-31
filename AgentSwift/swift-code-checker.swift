#!/usr/bin/swift

import Foundation

// SwiftCodeChecker command-line wrapper script
// Usage: swift swift-code-checker.swift [FILE_PATH] [OPTIONS]

// Parse command line arguments
var filePath: String?
var generateReport = false

// Simple argument parsing
for (index, arg) in CommandLine.arguments.enumerated() {
    if index == 0 { continue } // Skip program name
    
    if arg == "--report" || arg == "-r" {
        generateReport = true
    } else if arg == "--help" || arg == "-h" {
        printUsage()
        exit(0)
    } else if !arg.hasPrefix("-") && filePath == nil {
        // First non-flag argument is the file path
        filePath = arg
    }
}

func printUsage() {
    print("""
    Usage: swift swift-code-checker.swift FILE_PATH [OPTIONS]
    
    Swift Code Checker - A static analysis tool for Swift code
    
    Options:
      -r, --report    Generate a detailed Markdown report
      -h, --help      Display this help message
    
    Example:
      swift swift-code-checker.swift path/to/your/file.swift
      swift swift-code-checker.swift path/to/your/file.swift --report
    """)
}

// Check if file path is provided
guard let path = filePath else {
    print("Error: Please provide a Swift file path to check")
    printUsage()
    exit(1)
}

// Check if file exists
guard FileManager.default.fileExists(atPath: path) else {
    print("Error: File not found at path: \(path)")
    exit(1)
}

// Check if file is a Swift file
guard path.hasSuffix(".swift") else {
    print("Error: File must be a Swift file with .swift extension")
    exit(1)
}

// Run swift-checker-demo with the specified file
print("Running Swift Code Checker on: \(path)")
print("--------------------------------------\n")

// Build the command arguments
var arguments = ["swift", "run", "swift-checker-demo"]

// Add file path (required argument)
arguments.append(path)

// Add report option after the file path
if generateReport {
    arguments.append("--report")
    
    // Generate explicit report path
    let reportPath = "\(path)-report.md"
    arguments.append(reportPath)
    
    print("Will generate report at: \(reportPath)")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = arguments

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

do {
    try process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? "No output"
    
    print(output)
    
    // Check for successful report generation
    if generateReport {
        let reportPath = "\(path)-report.md"
        if FileManager.default.fileExists(atPath: reportPath) {
            print("\nReport successfully generated at: \(reportPath)")
        } else {
            print("\nWarning: Report file not found at: \(reportPath)")
        }
    }
    
    // Check exit status
    if process.terminationStatus != 0 {
        print("Error: Checker exited with status \(process.terminationStatus)")
        exit(Int32(process.terminationStatus))
    }
} catch {
    print("Error executing checker: \(error)")
    exit(1)
} 