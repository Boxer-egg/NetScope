import Foundation
import Combine

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var connectionStore = ConnectionStore()
    @Published var tracerouteStore = TracerouteStore()
    @Published var isFirstRun: Bool = false

    private let poller = ConnectionPoller(interval: 1.0)
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Synchronously check file existence to avoid async race with setup flow
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetScope/GeoLite2-City.mmdb")
        let fileExists = FileManager.default.fileExists(atPath: dbPath.path)
        self.isFirstRun = !fileExists

        // Async load database if file exists
        if fileExists {
            Task {
                await GeoDatabase.shared.loadDatabase()
            }
        }

        // Configure poller callback
        // The callback runs on a background Task within ConnectionPoller,
        // so we must hop back to MainActor to update the store.
        poller.onUpdate = { [weak self] connections in
            Task { @MainActor in
                self?.connectionStore.update(with: connections)
            }
        }

        // Start the background polling task
        poller.start()
    }

    func stopPolling() {
        poller.stop()
    }
}
