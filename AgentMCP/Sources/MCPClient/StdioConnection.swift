import Foundation

// MARK: - Stdio Connection (JSON-RPC over pipes)

/// Manages a server process and JSON-RPC communication via stdio pipes.
/// Uses readabilityHandler callbacks for fully non-blocking I/O.
final class StdioConnection: @unchecked Sendable, MCPConnection {
    let process: Process
    let writer: FileHandle
    let reader: FileHandle
    let errorReader: FileHandle
    private var nextId: Int = 0
    private let lock = NSLock()

    // Pending response continuations keyed by request id
    private var pending: [Int: CheckedContinuation<[String: Any], any Error>] = [:]
    private var buffer = Data()
    /// Maximum buffer size (10 MB) — disconnect server if exceeded
    private static let maxBufferSize = 10 * 1024 * 1024

    init(process: Process, writer: FileHandle, reader: FileHandle, errorReader: FileHandle) {
        self.process = process
        self.writer = writer
        self.reader = reader
        self.errorReader = errorReader

        // Drain stderr to prevent the server from blocking on a full pipe (64 KB OS limit)
        errorReader.readabilityHandler = { handle in
            _ = handle.availableData
        }

        // Set up non-blocking read via readabilityHandler
        reader.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }

            self.lock.lock()
            self.buffer.append(data)

            // Guard against unbounded buffer growth from malicious servers
            if self.buffer.count > Self.maxBufferSize {
                print("[MCPClient] Buffer exceeded \(Self.maxBufferSize) bytes — disconnecting server")
                self.buffer.removeAll()
                let pendingCopy = self.pending
                self.pending.removeAll()
                self.lock.unlock()
                for (_, continuation) in pendingCopy {
                    continuation.resume(throwing: MCPClientError.bufferOverflow)
                }
                self.disconnect()
                return
            }

            // Process complete newline-delimited messages
            while let newlineIndex = self.buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = self.buffer[self.buffer.startIndex..<newlineIndex]
                self.buffer = self.buffer[(newlineIndex + 1)...]

                guard !lineData.isEmpty,
                      let json = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any] else {
                    continue
                }

                // Match response to pending request
                var matchedId: Int?
                if let rid = json["id"] as? Int {
                    matchedId = rid
                } else if let rid = json["id"] as? String, let intId = Int(rid) {
                    matchedId = intId
                }

                if let id = matchedId, let continuation = self.pending.removeValue(forKey: id) {
                    self.lock.unlock()
                    continuation.resume(returning: json)
                    self.lock.lock()
                }
            }
            self.lock.unlock()
        }
    }

    /// Send a JSON-RPC request and await the response (non-blocking)
    func sendRequest(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = nextRequestId()

        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params { request["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: request)
        var message = data
        message.append(contentsOf: [UInt8(ascii: "\n")])

        return try await withCheckedThrowingContinuation { continuation in
            // Register pending before writing to avoid race
            lock.lock()
            pending[id] = continuation
            lock.unlock()

            writer.write(message)

            // Timeout after 15 minutes (MCP tools like domain checks can be slow)
            DispatchQueue.global().asyncAfter(deadline: .now() + 900) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                if let cont = self.pending.removeValue(forKey: id) {
                    self.lock.unlock()
                    cont.resume(throwing: MCPClientError.connectionFailed("Timeout waiting for \(method)"))
                } else {
                    self.lock.unlock()
                }
            }
        }
    }

    /// Send a JSON-RPC notification (no response expected)
    func sendNotification(method: String, params: [String: Any]? = nil) throws {
        var notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        if let params { notification["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: notification)
        var message = data
        message.append(contentsOf: [UInt8(ascii: "\n")])

        writer.write(message)
    }

    var isAlive: Bool { process.isRunning }

    func disconnect() {
        reader.readabilityHandler = nil
        errorReader.readabilityHandler = nil
        lock.lock()
        let leftover = pending
        pending.removeAll()
        lock.unlock()
        for (_, cont) in leftover {
            cont.resume(throwing: MCPClientError.connectionFailed("Disconnected"))
        }
        if process.isRunning {
            process.terminate()
            // Force-kill after 2 seconds if the server ignores SIGTERM
            let proc = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if proc.isRunning {
                    kill(proc.processIdentifier, SIGKILL)
                }
            }
        }
    }

    private func nextRequestId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        return nextId
    }
}
