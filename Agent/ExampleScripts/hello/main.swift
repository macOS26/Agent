import Foundation

print("Hello from Swift Script!")
print("========================")
print("Current directory: \(FileManager.default.currentDirectoryPath)")
print("Home directory: \(FileManager.default.homeDirectoryForCurrentUser.path)")
print("User name: \(NSUserName())")
print("Full name: \(NSFullUserName())")
print("Date: \(Date())")
print("Host name: \(ProcessInfo.processInfo.hostName)")
print("OS version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
