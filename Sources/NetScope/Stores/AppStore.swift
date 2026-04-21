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
        // Check if database exists to determine if we need onboarding
        checkDatabaseStatus()

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

    func checkDatabaseStatus() {
        Task {
            let hasDB = await GeoDatabase.shared.hasLocalDatabase()
            await MainActor.run {
                self.isFirstRun = !hasDB
            }
        }
    }

    func stopPolling() {
        poller.stop()
    }
}
