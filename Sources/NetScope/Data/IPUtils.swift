import Foundation

/// Checks if an IP address is in a private/non-routable range.
func isPrivateIP(_ ip: String) -> Bool {
    if ip == "*" || ip.isEmpty { return true }
    if ip == "::1" || ip == "localhost" { return true }
    if ip == "127.0.0.1" || ip == "0.0.0.0" { return true }
    if ip.hasSuffix(".local") || ip == "*.*" { return true }

    // IPv6: only apply prefix checks once we know it is an address
    if ip.contains(":") {
        let lower = ip.lowercased()
        return lower.hasPrefix("fe80:") || lower.hasPrefix("fc") || lower.hasPrefix("fd")
    }

    // IPv4: require exactly four numeric octets so hostnames are never matched
    let parts = ip.split(separator: ".")
    guard parts.count == 4, parts.allSatisfy({ Int($0) != nil }) else { return false }
    if parts[0] == "10" { return true }
    if parts[0] == "192" && parts[1] == "168" { return true }
    if parts[0] == "169" && parts[1] == "254" { return true }
    if parts[0] == "172", let second = Int(parts[1]), second >= 16 && second <= 31 { return true }
    if parts[0] == "127" { return true }
    return false
}
