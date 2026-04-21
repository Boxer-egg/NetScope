import Foundation

/// 负责轮询系统网络连接状态
/// 使用类（class）结合 Task 实现，以便于在 @MainActor 下同步配置
class ConnectionPoller {
    private let interval: TimeInterval
    private var pollingTask: Task<Void, Never>?

    /// 回调闭包，在后台线程执行
    var onUpdate: (([Connection]) -> Void)?

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func start() {
        stop()

        pollingTask = Task {
            while !Task.isCancelled {
                // 执行 lsof 命令
                let output = shell("/usr/sbin/lsof -nP -iTCP -iUDP -sTCP:ESTABLISHED,LISTEN")
                let connections = parseLsof(output)

                // 触发回调
                onUpdate?(connections)

                // 等待下一个周期
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

// MARK: - lsof Parsing (保持不变)

private let lsofLineRegex = try! NSRegularExpression(
    pattern: "^(.+?)\\s+(\\d+)\\s+.*?(?:IPv4|IPv6).*?(TCP|UDP)\\s+(.*)$",
    options: []
)

private let connectionRegex = try! NSRegularExpression(
    pattern: #"(\S+):(\d+)->(\S+):(\d+)"#,
    options: []
)

private let ipv6ConnectionRegex = try! NSRegularExpression(
    pattern: #"\[(.*?)\]:(\d+)->\[(.*?)\]:(\d+)"#,
    options: []
)

func parseLsof(_ output: String) -> [Connection] {
    var connections: [Connection] = []
    let lines = output.components(separatedBy: .newlines)

    for line in lines {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = lsofLineRegex.firstMatch(in: line, options: [], range: range) else { continue }

        let commandRange = Range(match.range(at: 1), in: line)!
        let pidRange = Range(match.range(at: 2), in: line)!
        let protoRange = Range(match.range(at: 3), in: line)!
        let nameRange = Range(match.range(at: 4), in: line)!

        let processName = String(line[commandRange])
        guard let pid = Int(line[pidRange]) else { continue }
        let proto = String(line[protoRange])
        let nameField = String(line[nameRange])

        if let conn = parseConnectionField(nameField, pid: pid, processName: processName, proto: proto) {
            connections.append(conn)
        }
    }

    return connections
}

private func parseConnectionField(_ field: String, pid: Int, processName: String, proto: String) -> Connection? {
    if let match = ipv6ConnectionRegex.firstMatch(in: field, options: [], range: NSRange(field.startIndex..., in: field)) {
        let localPort = Int(field[Range(match.range(at: 2), in: field)!])!
        let remoteIP = String(field[Range(match.range(at: 3), in: field)!]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let remotePort = Int(field[Range(match.range(at: 4), in: field)!])!

        if isPrivateIP(remoteIP) { return nil }

        let state = field.contains("ESTABLISHED") ? "ESTABLISHED" : "OTHER"
        return Connection(pid: pid, processName: processName, localPort: localPort,
                         remoteIP: remoteIP, remotePort: remotePort, proto: proto, state: state)
    }

    if let match = connectionRegex.firstMatch(in: field, options: [], range: NSRange(field.startIndex..., in: field)) {
        let localPort = Int(field[Range(match.range(at: 2), in: field)!])!
        let remoteIP = String(field[Range(match.range(at: 3), in: field)!])
        let remotePort = Int(field[Range(match.range(at: 4), in: field)!])!

        if isPrivateIP(remoteIP) { return nil }

        let state = field.contains("ESTABLISHED") ? "ESTABLISHED" : "OTHER"
        return Connection(pid: pid, processName: processName, localPort: localPort,
                         remoteIP: remoteIP, remotePort: remotePort, proto: proto, state: state)
    }

    return nil
}

func isPrivateIP(_ ip: String) -> Bool {
    if ip.hasPrefix("127.") || ip == "::1" || ip == "localhost" { return true }
    if ip.hasPrefix("10.") { return true }
    if ip.hasPrefix("192.168.") { return true }
    if ip.hasPrefix("172.") {
        let parts = ip.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
            return true
        }
    }
    if ip.hasPrefix("fc00:") || ip.hasPrefix("fd00:") { return true }
    if ip.hasPrefix("fe80:") || ip.hasPrefix("fe80::") { return true }
    if ip == "*" || ip.hasPrefix("[::]") { return true }
    if ip.hasPrefix("fe80") {
        let remainder = ip.dropFirst(4)
        if remainder.hasPrefix(":") || remainder.hasPrefix("::") {
            return true
        }
    }
    return false
}

// MARK: - Shell helper

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.environment = ["PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]

    do {
        try task.run()
    } catch {
        return ""
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
