import Foundation
import Combine

class ConnectionProvider: ObservableObject {
    @Published private(set) var activeSource: ConnectionSource
    var onUpdate: (([Connection]) -> Void)?
    var onFailure: ((String) -> Void)?

    private let sources: [ConnectionSource]

    init(sources: [ConnectionSource]) {
        precondition(!sources.isEmpty, "ConnectionProvider requires at least one source")
        self.sources = sources
        self.activeSource = sources.first!
    }

    func start() {
        wireCallbacks(for: activeSource)
        activeSource.start()
    }

    func stop() {
        activeSource.onUpdate = nil
        activeSource.onFailure = nil
        activeSource.stop()
    }

    func restart() {
        activeSource.stop()
        activeSource.start()
    }

    func setPollInterval(_ interval: TimeInterval) {
        for source in sources {
            source.pollInterval = interval
        }
    }

    func switchTo(sourceNamed name: String) {
        guard let newSource = sources.first(where: { $0.displayName == name }),
              newSource.displayName != activeSource.displayName else {
            return
        }

        activeSource.stop()
        activeSource.onUpdate = nil
        activeSource.onFailure = nil

        activeSource = newSource
        wireCallbacks(for: activeSource)
        activeSource.start()
    }

    private func wireCallbacks(for source: ConnectionSource) {
        source.onUpdate = { [weak self] connections in
            self?.onUpdate?(connections)
        }
        source.onFailure = { [weak self] reason in
            self?.onFailure?(reason)
        }
    }

    var availableSources: [String] {
        sources.map { $0.displayName }
    }
}
