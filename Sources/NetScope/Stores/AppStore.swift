import Foundation
import Combine

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var connectionStore = ConnectionStore()
    @Published var tracerouteStore = TracerouteStore()
    @Published var isFirstRun: Bool = false

    private let provider: ConnectionProvider
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetScope/GeoLite2-City.mmdb")
        let fileExists = FileManager.default.fileExists(atPath: dbPath.path)
        self.isFirstRun = !fileExists

        if fileExists {
            Task {
                await GeoDatabase.shared.loadDatabase()
            }
        }

        let nettopSource = NettopConnectionSource(interval: 1.0)
        let nwsSource = NetworkStatisticsSource()
        self.provider = ConnectionProvider(sources: [nettopSource, nwsSource])

        provider.onUpdate = { [weak self] connections in
            Task { @MainActor in
                self?.connectionStore.update(with: connections)
            }
        }

        provider.start()
    }

    func stopPolling() {
        provider.stop()
    }

    func switchDataSource(to name: String) {
        provider.switchTo(sourceNamed: name)
        connectionStore.reset()
    }

    var availableDataSources: [String] {
        provider.availableSources
    }
}
