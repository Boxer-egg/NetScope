import Foundation
import Combine

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var connectionStore = ConnectionStore()
    @Published var tracerouteStore = TracerouteStore()
    @Published var isFirstRun: Bool = false
    @Published var isPaused: Bool = false
    @Published var dataSourceWarning: String? = nil

    private let provider: ConnectionProvider
    private let settings = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetScope/GeoLite2-City.mmdb")
        let fileExists = FileManager.default.fileExists(atPath: dbPath.path)
        self.isFirstRun = !fileExists && !settings.hasSkippedSetup

        if fileExists {
            Task {
                await GeoDatabase.shared.loadDatabase()
            }
        }

        let allowOnline = settings.allowOnlineGeoIP
        Task {
            await GeoDatabase.shared.setAllowOnlineFallback(allowOnline)
        }

        let nwsSource = NetworkStatisticsSource()
        let nettopSource = NettopConnectionSource(interval: settings.refreshInterval)
        self.provider = ConnectionProvider(sources: [nwsSource, nettopSource])
        provider.setPollInterval(settings.refreshInterval)

        provider.onUpdate = { [weak self] connections in
            Task { @MainActor in
                self?.connectionStore.update(with: connections)
            }
        }

        provider.onFailure = { [weak self] reason in
            Task { @MainActor in
                self?.handleSourceFailure(reason: reason)
            }
        }

        connectionStore.isLoading = true
        provider.start()
    }

    private func handleSourceFailure(reason: String) {
        guard reason == "NetworkStatisticsUnavailable" else { return }
        connectionStore.isLoading = true
        provider.switchTo(sourceNamed: "nettop")
        connectionStore.reset()
        connectionStore.isLoading = true
        dataSourceWarning = String(localized: "The NetworkStatistics source is unavailable on this system. Switched to nettop.", bundle: .module)
    }

    func dismissDataSourceWarning() {
        dataSourceWarning = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            provider.stop()
        } else {
            connectionStore.isLoading = true
            provider.start()
        }
    }

    func applyRefreshInterval() {
        provider.setPollInterval(settings.refreshInterval)
        guard !isPaused else { return }
        provider.restart()
    }

    func skipSetup() {
        settings.hasSkippedSetup = true
        isFirstRun = false
    }

    func stopPolling() {
        provider.stop()
    }

    func switchDataSource(to name: String) {
        dataSourceWarning = nil
        provider.switchTo(sourceNamed: name)
        connectionStore.reset()
        connectionStore.isLoading = true
    }

    var availableDataSources: [String] {
        provider.availableSources
    }

    var currentDataSource: String {
        provider.activeSource.displayName
    }
}
