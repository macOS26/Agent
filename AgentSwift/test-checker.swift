#!/usr/bin/swift

import Foundation

// Get the directory of the script
let scriptPath = CommandLine.arguments[0]
let scriptDir = URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path

// Path to the test file
let testFilePath = "\(scriptDir)/test.swift"

// Compile and run swift-checker-demo first
print("Running tests on: \(testFilePath)\n")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["swift", "run", "swift-checker-demo"]
process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

try process.run()
process.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? "No output"

print(output) 