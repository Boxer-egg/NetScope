import Foundation
import AppKit

class NettopConnectionSource: ConnectionSource {
    var pollInterval: TimeInterval
    private var task: Task<Void, Never>?
    private var process: Process?
    private let processLock = NSLock()
    var onUpdate: (([Connection]) -> Void)?
    var onFailure: ((String) -> Void)?

    var displayName: String { "nettop" }

    init(interval: TimeInterval = 1.0) {
        self.pollInterval = interval
    }

    func start() {
        stop()
        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        processLock.lock()
        process?.terminate()
        process = nil
        processLock.unlock()
    }

    // MARK: - Continuous Polling

    private func runLoop() async {
        var backoff: TimeInterval = 0.5
        while !Task.isCancelled {
            let succeeded = await runOnce()
            if Task.isCancelled { break }
            if !succeeded {
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff = min(backoff * 2, 5)
            } else {
                backoff = 0.5
            }
        }
    }

    /// Spawns a single long-lived `nettop -L 0` process and streams its CSV
    /// output until it exits. Emits one update per sample batch.
    private func runOnce() async -> Bool {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        p.arguments = ["-L", "0", "-x", "-t", "external", "-s", "\(max(1, Int(pollInterval.rounded())))"]
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
        } catch {
            return false
        }

        processLock.lock()
        process = p
        processLock.unlock()

        var batchText = ""
        var lastTimeToken: String?
        let handle = pipe.fileHandleForReading

        do {
            for try await line in handle.bytes.lines {
                if Task.isCancelled { break }
                if line.isEmpty { continue }

                let timeToken = String(line.prefix(8))
                if let last = lastTimeToken, timeToken != last {
                    if !batchText.isEmpty {
                        let output = batchText
                        batchText = ""
                        onUpdate?(parseNettopOutput(output))
                    }
                }
                lastTimeToken = timeToken
                batchText += line + "\n"
            }
        } catch {
            batchText = ""
        }

        if !batchText.isEmpty && !Task.isCancelled {
            onUpdate?(parseNettopOutput(batchText))
        }

        processLock.lock()
        process = nil
        processLock.unlock()
        return true
    }

    // MARK: - Parser (COLUMN-INDEX BASED, no regex for extraction)

    func parseNettopOutput(_ output: String) -> [Connection] {
        var connections: [Connection] = []
        let lines = output.components(separatedBy: .newlines)
        let runningApps = NSWorkspace.shared.runningApplications  // snapshot once per poll

        var currentProcessName = ""
        var currentPid = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let cols = trimmed.components(separatedBy: ",")
            guard cols.count >= 3 else { continue }

            // Skip header line
            if cols[0] == "time" || !cols[0].contains(":") {
                continue
            }

            let col2 = cols[1].trimmingCharacters(in: .whitespaces)

            if col2.contains("<->") {
                // Connection row
                guard !currentProcessName.isEmpty else { continue }
                guard let conn = parseConnectionRow(cols, processName: currentProcessName, pid: currentPid) else { continue }
                connections.append(conn)
            } else if let lastDot = col2.lastIndex(of: ".") {
                // Process row: "processName.PID"
                let afterDot = String(col2[col2.index(after: lastDot)...])
                if let pid = Int(afterDot), pid > 0 {
                    let rawName = String(col2[..<lastDot]).trimmingCharacters(in: .whitespaces)
                    currentPid = pid
                    currentProcessName = resolveFriendlyProcessName(rawName, pid: pid, runningApps: runningApps)
                }
            }
        }

        return connections
    }

    private func parseConnectionRow(_ cols: [String], processName: String, pid: Int) -> Connection? {
        guard cols.count >= 6 else { return nil }

        let col2 = cols[1].trimmingCharacters(in: .whitespaces)
        let parts = col2.components(separatedBy: .whitespaces)
        guard parts.count >= 2 else { return nil }

        let proto = parts[0].uppercased()
        let addrPart = parts[1]

        guard let arrowRange = addrPart.range(of: "<->") else { return nil }
        let localAddr = String(addrPart[..<arrowRange.lowerBound])
        let remoteAddr = String(addrPart[arrowRange.upperBound...])

        let (remoteIP, remotePort) = parseAddress(remoteAddr)
        let (_, localPort) = parseAddress(localAddr)

        // Skip wildcard/listening sockets that don't represent actual external connections
        if remoteIP == "*" || remoteIP == "*.*" || remoteIP.isEmpty || remotePort == 0 {
            return nil
        }

        let state = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : "Unknown"
        let bytesIn = cols.count > 4 ? (Int64(cols[4].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
        let bytesOut = cols.count > 5 ? (Int64(cols[5].trimmingCharacters(in: .whitespaces)) ?? 0) : 0

        return Connection(
            pid: pid,
            processName: processName,
            localPort: localPort,
            remoteIP: remoteIP,
            remotePort: remotePort,
            proto: proto,
            state: state.isEmpty ? "Unknown" : state,
            bytesIn: bytesIn,
            bytesOut: bytesOut
        )
    }

    // MARK: - Process Name Resolution

    private func resolveFriendlyProcessName(_ rawName: String, pid: Int, runningApps: [NSRunningApplication]) -> String {
        if pid > 0,
           let app = runningApps.first(where: { $0.processIdentifier == pid }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        if let app = runningApps.first(where: { $0.localizedName == rawName }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        if let app = runningApps.first(where: {
            guard let locName = $0.localizedName else { return false }
            return rawName.hasPrefix(locName) || locName.hasPrefix(rawName)
        }), let friendlyName = app.localizedName, !friendlyName.isEmpty {
            return friendlyName
        }

        return rawName
    }

    // MARK: - Address Parser

    private func parseAddress(_ addr: String) -> (ip: String, port: Int) {
        let trimmed = addr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", 0) }

        if let lastColon = trimmed.lastIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: lastColon)...])
            let ip = String(trimmed[..<lastColon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]* "))
            if let port = Int(afterColon), port >= 0 && port <= 65535 {
                return (ip, port)
            } else {
                return (ip, 0)
            }
        }

        if let lastDot = trimmed.lastIndex(of: ".") {
            let afterDot = String(trimmed[trimmed.index(after: lastDot)...])
            if let port = Int(afterDot), port > 0 && port <= 65535 {
                let prefix = String(trimmed[..<lastDot])
                let prefixParts = prefix.split(separator: ".")
                if let lastPart = prefixParts.last, Int(lastPart) == nil {
                    return (prefix, port)
                }
            }
        }

        return (trimmed, 0)
    }

}
