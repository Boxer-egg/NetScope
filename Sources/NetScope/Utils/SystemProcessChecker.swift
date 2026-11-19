import Foundation
import Darwin

enum SystemProcessChecker {
    private static var cache: [Int32: Bool] = [:]
    private static let cacheLimit = 4000

    private static let systemPrefixes = [
        "/System/", "/usr/sbin/", "/usr/libexec/", "/usr/lib/", "/sbin/"
    ]

    /// Returns true when the process executable lives in an Apple system
    /// location (daemons, XPC helpers, framework agents).
    static func isSystemProcess(pid: Int) -> Bool {
        guard pid > 0 else { return false }
        let key = pid_t(pid)
        if let cached = cache[key] { return cached }

        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(key, &buffer, UInt32(MAXPATHLEN))

        var isSystem = false
        if length > 0 {
            let path = String(cString: buffer)
            isSystem = systemPrefixes.contains { path.hasPrefix($0) }
        }

        if cache.count >= cacheLimit {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = isSystem
        return isSystem
    }
}
