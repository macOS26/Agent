// SystemInfo.swift
// A Swift AgentScript to gather detailed system and user information.

import Foundation
import SystemConfiguration
import Darwin

// MARK: - Helper Functions

/// Execute a shell command and return its output.
/// - Parameter command: The command to execute.
/// - Returns: The command output as a string, or error message.
func shell(_ command: String) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
    } catch {
        return "Error: \(error.localizedDescription)"
    }
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Error executing command"
}

/// Get the current public IP address.
/// - Returns: The public IP address as a string.
func getPublicIP() -> String {
    guard let url = URL(string: "https://api.ipify.org?format=text") else { return "Unknown" }
    do {
        return try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return "Unknown"
    }
}

/// Get the local IP address.
/// - Returns: The local IP address as a string.
func getLocalIP() -> String {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            let interface = ptr?.pointee
            guard let ifa_name = interface?.ifa_name,
                  let ifa_addr = interface?.ifa_addr else { continue }
            let addrFamily = ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let saLen = ifa_addr.pointee.sa_len
                    getnameinfo(ifa_addr, socklen_t(saLen), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address ?? "Unknown"
}

/// Get the current network SSID.
/// - Returns: The SSID as a string.
func getSSID() -> String {
    let output = shell("networksetup -getairportnetwork en0")
    // Output: "Current Wi-Fi Network: MyNetwork"
    if let range = output.range(of: ": ") {
        return String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "Unknown"
}

/// Get the current CPU usage.
/// - Returns: CPU usage as a percentage string.
func getCPUUsage() -> String {
    var totalUsageOfCPU: Double = 0.0
    var threadsList: thread_act_array_t?
    var threadsCount = mach_msg_type_number_t(0)
    let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
        $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }
    }

    if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
        for index in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            guard infoResult == KERN_SUCCESS else {
                continue
            }

            let threadBasicInfo = threadInfo as thread_basic_info
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
            }
        }
    }

    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadsList), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
    return String(format: "%.1f%%", totalUsageOfCPU)
}

/// Get the current memory usage.
/// - Returns: Memory usage details as a string.
func getMemoryUsage() -> String {
    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
    let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        let usedBytes = Int64(taskInfo.phys_footprint)
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
        let freeBytes = totalBytes - usedBytes

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file

        return "Total: \(formatter.string(fromByteCount: totalBytes)), Used: \(formatter.string(fromByteCount: usedBytes)), Free: \(formatter.string(fromByteCount: freeBytes))"
    } else {
        return "Unknown"
    }
}

/// Get the current disk usage.
/// - Returns: Disk usage details as a string.
func getDiskUsage() -> String {
    let fileURL = URL(fileURLWithPath: "/")
    do {
        let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity else { return "Unknown" }

        let used = total - free
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file

        return "Total: \(formatter.string(fromByteCount: Int64(total))), Used: \(formatter.string(fromByteCount: Int64(used))), Free: \(formatter.string(fromByteCount: Int64(free)))"
    } catch {
        return "Unknown"
    }
}

/// Get the current battery level using `pmset`.
/// - Returns: Battery level as a percentage string.
func getBatteryLevel() -> String {
    let output = shell("pmset -g batt | grep -Eo '\\d+%'")
    return output.isEmpty ? "Unknown" : output
}

/// Get the current screen resolution.
/// - Returns: Screen resolution as a string.
func getScreenResolution() -> String {
    let output = shell("system_profiler SPDisplaysDataType")
    for line in output.components(separatedBy: .newlines) {
        if line.contains("Resolution") {
            return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        }
    }
    return "Unknown"
}

/// Get the current active processes.
/// - Returns: A string listing the top 5 active processes.
func getActiveProcesses() -> String {
    let output = shell("ps -arcwwwxo 'pid,pcpu,pmem,command' | head -n 6")
    return output
}

/// Get the current logged-in user's full name.
/// - Returns: The full name as a string.
func getFullName() -> String {
    let output = shell("id -F")
    return output.isEmpty ? "Unknown" : output
}

/// Get the current user's home directory size.
/// - Returns: Home directory size as a string.
func getHomeDirectorySize() -> String {
    let output = shell("du -sh ~ | cut -f1")
    return output.isEmpty ? "Unknown" : output
}

/// Get the current system uptime.
/// - Returns: System uptime as a string.
func getUptime() -> String {
    let output = shell("uptime")
    return output.isEmpty ? "Unknown" : output
}

/// Get the current system temperature.
/// - Returns: System temperature as a string.
func getSystemTemperature() -> String {
    let output = shell("istats scan | grep -E 'CPU Temperature|System Temperature'")
    return output.isEmpty ? "Unknown" : output
}

// MARK: - Main Function

@_cdecl("script_main") public func scriptMain() -> Int32 {
    // Gather all system and user information
    let username = NSUserName()
    let fullName = getFullName()
    let computerName = Host.current().localizedName ?? "Unknown"
    let hostName = ProcessInfo.processInfo.hostName
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    let currentDate = Date().description
    let uptime = getUptime()
    let publicIP = getPublicIP()
    let localIP = getLocalIP()
    let ssid = getSSID()
    let cpuUsage = getCPUUsage()
    let memoryUsage = getMemoryUsage()
    let diskUsage = getDiskUsage()
    let batteryLevel = getBatteryLevel()
    let screenResolution = getScreenResolution()
    let activeProcesses = getActiveProcesses()
    let homeDirectorySize = getHomeDirectorySize()
    let systemTemperature = getSystemTemperature()

    // Print all gathered information
    print("\n=== System and User Information ===\n")
    print("• Username: \(username)")
    print("• Full Name: \(fullName)")
    print("• Computer Name: \(computerName)")
    print("• Host Name: \(hostName)")
    print("• OS Version: \(osVersion)")
    print("• Current Date: \(currentDate)")
    print("• Uptime: \(uptime)")
    print("\n=== Network Information ===\n")
    print("• Public IP: \(publicIP)")
    print("• Local IP: \(localIP)")
    print("• SSID: \(ssid)")
    print("\n=== System Usage ===\n")
    print("• CPU Usage: \(cpuUsage)")
    print("• Memory Usage: \(memoryUsage)")
    print("• Disk Usage: \(diskUsage)")
    print("• Battery Level: \(batteryLevel)")
    print("• Screen Resolution: \(screenResolution)")
    print("• System Temperature: \(systemTemperature)")
    print("\n=== Home Directory ===\n")
    print("• Home Directory Size: \(homeDirectorySize)")
    print("\n=== Active Processes (Top 5) ===\n")
    print(activeProcesses)
    print("\n=== End of Report ===\n")

    return 0
}