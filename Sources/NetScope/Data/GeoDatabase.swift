import Foundation
import MaxMindDB

actor GeoDatabase {
    static let shared = GeoDatabase()

    private var reader: MaxMindDBReader?
    private var cache: [String: GeoInfo] = [:]
    private var cacheCapacity = 2000
    private var cacheKeys: [String] = []
    private var hasAttemptedLoad = false


    // Privacy and API settings
    var allowOnlineFallback: Bool = true
    private var lastAPITime: Date = .distantPast
    private let minAPIInterval: TimeInterval = 1.5 // ~40 req/min safe margin
    private var pendingLookups: [String: Task<GeoInfo?, Never>] = [:]

    private init() {}

    func loadDatabase() {
        if hasAttemptedLoad && reader != nil { return }
        hasAttemptedLoad = true
        let paths = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/NetScope/GeoLite2-City.mmdb"),
            Bundle.main.url(forResource: "GeoLite2-City", withExtension: "mmdb"),
        ].compactMap { $0 }

        for path in paths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    reader = try MaxMindDBReader(database: path)
                    print("[GeoDatabase] Loaded: \(path.path)")
                    return
                } catch {
                    print("[GeoDatabase] Failed to load \(path.path): \(error)")
                }
            }
        }
        print("[GeoDatabase] No local database found.")
    }

    func hasLocalDatabase() -> Bool {
        reader != nil
    }

    func lookup(ip: String) async -> GeoInfo? {
        // Skip private/local IPs — they have no public geo location
        if isPrivateIP(ip) {
            return nil
        }

        if let cached = cache[ip] {
            return cached
        }

        // Deduplicate concurrent lookups for same IP
        if let pending = pendingLookups[ip] {
            return await pending.value
        }

        let task = Task<GeoInfo?, Never> {
            defer { pendingLookups.removeValue(forKey: ip) }
            let result = await performLookup(ip: ip)
            if let result = result {
                print("[GeoDatabase] Successfully resolved \(ip) to \(result.country)")
                insertCache(ip: ip, geo: result)
            } else {
                print("[GeoDatabase] Failed to resolve \(ip)")
            }
            return result
        }

        pendingLookups[ip] = task
        return await task.value
    }

    private func performLookup(ip: String) async -> GeoInfo? {
        // Ensure database is loaded
        if reader == nil {
            loadDatabase()
        }

        // 1. Try MaxMindDB local
        if let reader = reader {
            do {
                let city = try reader.city(ip)
                return GeoInfo(
                    latitude: city.location?.latitude ?? 0,
                    longitude: city.location?.longitude ?? 0,
                    city: city.city?.names[.english],
                    country: city.country?.names[.english] ?? "Unknown",
                    countryCode: city.country?.isoCode ?? "",
                    asn: nil
                )
            } catch {
                // Local lookup failed
            }
        }

        // 2. Fallback to ip-api.com (Only if explicitly allowed)
        if allowOnlineFallback {
            return await lookupOnline(ip: ip)
        }

        return nil
    }

    private func lookupOnline(ip: String) async -> GeoInfo? {
        let now = Date()
        let waitTime = minAPIInterval - now.timeIntervalSince(lastAPITime)
        if waitTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastAPITime = Date()

        let url = URL(string: "http://ip-api.com/json/\(ip)?fields=status,message,country,countryCode,city,lat,lon,as,query")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "success",
               let lat = json["lat"] as? Double,
               let lon = json["lon"] as? Double {
                return GeoInfo(
                    latitude: lat,
                    longitude: lon,
                    city: json["city"] as? String,
                    country: json["country"] as? String ?? "Unknown",
                    countryCode: json["countryCode"] as? String ?? "",
                    asn: json["as"] as? String
                )
            }
        } catch {
            print("[GeoDatabase] Online lookup failed for \(ip): \(error)")
        }
        return nil
    }

    private func insertCache(ip: String, geo: GeoInfo) {
        if cache.count >= cacheCapacity, let oldest = cacheKeys.first {
            cache.removeValue(forKey: oldest)
            cacheKeys.removeFirst()
        }
        cache[ip] = geo
        cacheKeys.append(ip)
    }
}
