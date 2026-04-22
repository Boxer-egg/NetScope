import Foundation

/// Checks if an IP address is in a private/non-routable range.
func isPrivateIP(_ ip: String) -> Bool {
    if ip == "*" || ip.isEmpty { return true }
    if ip == "::1" || ip == "localhost" { return true }
    if ip == "127.0.0.1" || ip == "0.0.0.0" { return true }
    if ip.hasPrefix("10.") || ip.hasPrefix("192.168.") || ip.hasPrefix("169.254.") { return true }
    if ip.hasPrefix("172.") {
        let parts = ip.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
            return true
        }
    }
    if ip.lowercased().hasPrefix("fe80:") || ip.lowercased().hasPrefix("fc") || ip.lowercased().hasPrefix("fd") {
        return true
    }
    if ip.hasSuffix(".local") || ip == "*.*" { return true }
    return false
}

/// Executes a shell command and returns its stdout as a string.
/// Returns empty string on failure.
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

    // Add 5-second timeout
    let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
        task.terminate()
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    timeoutTimer.invalidate()
    return String(data: data, encoding: .utf8) ?? ""
}
