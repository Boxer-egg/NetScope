import Foundation
import AppKit

class ConnectionPoller {
    private let interval: TimeInterval
    private var pollingTask: Task<Void, Never>?
    var onUpdate: (([Connection]) -> Void)?

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func start() {
        stop()
        pollingTask = Task {
            while !Task.isCancelled {
                // 获取外部连接的进程和连接详情（注意：-P 会隐藏连接详情）
                let output = shell("/usr/bin/nettop -L 1 -t external")
                let connections = parseNettopRobust(output)
                onUpdate?(connections)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func parseNettopRobust(_ output: String) -> [Connection] {
        var connections: [Connection] = []
        let lines = output.components(separatedBy: .newlines)

        var currentProcessName = ""
        var currentPid = 0

        // 正则表达式 1: 匹配进程标题 (例如: "Safari.1234" 或 "Edge .772")
        let procRegex = try? NSRegularExpression(pattern: "^[^,]+,\\s*(.+?)\\s*\\.(\\d+)", options: [])

        // 正则表达式 2: 匹配连接详情 (例如: "tcp4 1.2.3.4:56<->8.8.8.8:443")
        let connRegex = try? NSRegularExpression(pattern: "^[^,]+,\\s*(tcp[46]|udp[46])\\s+(.+?)<->(.+?),", options: [])

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            if let connMatch = connRegex?.firstMatch(in: line, options: [], range: range) {
                // --- 这是一个连接行 ---
                guard !currentProcessName.isEmpty else { continue }

                let proto = nsLine.substring(with: connMatch.range(at: 1)).uppercased()
                let localAddr = nsLine.substring(with: connMatch.range(at: 2))
                let remoteAddr = nsLine.substring(with: connMatch.range(at: 3))

                // 提取远端 IP 和 端口
                let (remoteIP, remotePort) = parseAddress(remoteAddr)

                // 提取本地端口
                let (_, localPort) = parseAddress(localAddr)

                // 提取 interface、state、流量（逗号分隔的第 3、4、5、6 列）
                let cols = line.components(separatedBy: ",")
                let state = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : "Unknown"
                let bytesIn = cols.count > 4 ? (Int64(cols[4]) ?? 0) : 0
                let bytesOut = cols.count > 5 ? (Int64(cols[5]) ?? 0) : 0

                let conn = Connection(
                    pid: currentPid,
                    processName: currentProcessName,
                    localPort: localPort,
                    remoteIP: remoteIP,
                    remotePort: remotePort,
                    proto: proto,
                    state: state.isEmpty ? "Unknown" : state,
                    bytesIn: bytesIn,
                    bytesOut: bytesOut
                )
                connections.append(conn)

            } else if let procMatch = procRegex?.firstMatch(in: line, options: [], range: range) {
                // --- 这是一个进程标题行 ---
                let rawName = nsLine.substring(with: procMatch.range(at: 1)).trimmingCharacters(in: .whitespaces)
                currentPid = Int(nsLine.substring(with: procMatch.range(at: 2))) ?? 0
                currentProcessName = resolveFriendlyProcessName(rawName, pid: currentPid)
            }
        }
        return connections
    }

    // MARK: - Process Name Resolution

    private func resolveFriendlyProcessName(_ rawName: String, pid: Int) -> String {
        let runningApps = NSWorkspace.shared.runningApplications

        // 1. Match by PID (most reliable)
        if pid > 0,
           let app = runningApps.first(where: { $0.processIdentifier == pid }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        // 2. Exact localizedName match
        if let app = runningApps.first(where: { $0.localizedName == rawName }),
           let friendlyName = app.localizedName,
           !friendlyName.isEmpty {
            return friendlyName
        }

        // 3. Partial match: rawName starts with localizedName
        //    (e.g. "Google Chrome H" → "Google Chrome")
        if let app = runningApps.first(where: {
            guard let locName = $0.localizedName else { return false }
            return rawName.hasPrefix(locName) || locName.hasPrefix(rawName)
        }), let friendlyName = app.localizedName, !friendlyName.isEmpty {
            return friendlyName
        }

        // 4. Fallback: keep original
        return rawName
    }

    private func parseAddress(_ addr: String) -> (ip: String, port: Int) {
        let trimmed = addr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", 0) }

        // IPv4 / bracketed IPv6: 用最后一个冒号分割 (e.g. 192.168.1.1:443, [fe80::1]:443, *:*)
        if let lastColon = trimmed.lastIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: lastColon)...])
            let ip = String(trimmed[..<lastColon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]* "))
            if let port = Int(afterColon), port >= 0 && port <= 65535 {
                return (ip, port)
            } else {
                // 冒号后不是数字（如 *:*），返回 IP 部分，端口为 0
                return (ip, 0)
            }
        }

        // 无冒号但末尾是 .数字，当作域名+端口 (e.g. ipad-mini.local.49277)
        if let lastDot = trimmed.lastIndex(of: ".") {
            let afterDot = String(trimmed[trimmed.index(after: lastDot)...])
            if let port = Int(afterDot), port > 0 && port <= 65535 {
                let prefix = String(trimmed[..<lastDot])
                // 避免把 192.168.1.1 的最后一个 1 误当端口（倒数第二段也是数字）
                let prefixParts = prefix.split(separator: ".")
                if let lastPart = prefixParts.last, Int(lastPart) == nil {
                    return (prefix, port)
                }
            }
        }

        return (trimmed, 0)
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

func shell(_ command: String) -> String {
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
