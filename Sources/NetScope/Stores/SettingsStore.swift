import Foundation
import Combine

@MainActor
class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    static let refreshIntervalKey = "refreshInterval"
    static let allowOnlineGeoIPKey = "allowOnlineGeoIP"
    static let hasSkippedSetupKey = "hasSkippedSetup"

    @Published var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey) }
    }

    @Published var allowOnlineGeoIP: Bool {
        didSet {
            UserDefaults.standard.set(allowOnlineGeoIP, forKey: Self.allowOnlineGeoIPKey)
            Task { await GeoDatabase.shared.setAllowOnlineFallback(allowOnlineGeoIP) }
        }
    }

    @Published var hasSkippedSetup: Bool {
        didSet { UserDefaults.standard.set(hasSkippedSetup, forKey: Self.hasSkippedSetupKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        let interval = defaults.double(forKey: Self.refreshIntervalKey)
        self.refreshInterval = interval > 0 ? interval : 1.0
        self.allowOnlineGeoIP = defaults.object(forKey: Self.allowOnlineGeoIPKey) as? Bool ?? true
        self.hasSkippedSetup = defaults.bool(forKey: Self.hasSkippedSetupKey)
    }
}
