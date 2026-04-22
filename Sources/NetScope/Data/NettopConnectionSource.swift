import Foundation
import AppKit

class NettopConnectionSource: ConnectionSource {
    private let interval: TimeInterval
    private var pollingTask: Task<Void, Never>?
    var onUpdate: (([Connection]) -> Void)?

    var displayName: String { "nettop" }

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func start() {
        stop()
        pollingTask = Task {
            while !Task.isCancelled {
                let output = shell("/usr/bin/nettop -L 1 -t external")
                let connections = parseNettopOutput(output)
                onUpdate?(connections)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Parser (COLUMN-INDEX BASED, no regex for extraction)

    func parseNettopOutput(_ output: String) -> [Connection] {
        var connections: [Connection] = []
        let lines = output.components(separatedBy: .newlines)

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
                    currentProcessName = resolveFriendlyProcessName(rawName, pid: pid)
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

    private func resolveFriendlyProcessName(_ rawName: String, pid: Int) -> String {
        let runningApps = NSWorkspace.shared.runningApplications

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

    // MARK: - Shell

    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.environment = ["PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        do { try task.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

func isPrivateIP(_ ip: String) -> Bool {
    if ip == "*" || ip.isEmpty || ip == "::1" || ip == "localhost" || ip == "127.0.0.1" || ip == "0.0.0.0" { return true }
    if ip.hasPrefix("10.") || ip.hasPrefix("192.168.") || ip.hasPrefix("169.254.") { return true }
    if ip.hasPrefix("172.") {
        let parts = ip.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
            return true
        }
    }
    if ip.hasPrefix("fe80:") || ip.hasPrefix("fc") || ip.hasPrefix("fd") { return true }
    if ip.hasSuffix(".local") || ip == "*.*" { return true }
    return false
}
