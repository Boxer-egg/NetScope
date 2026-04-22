import Foundation
import Combine

class ConnectionProvider: ObservableObject {
    @Published private(set) var activeSource: ConnectionSource
    var onUpdate: (([Connection]) -> Void)?

    private let sources: [ConnectionSource]

    init(sources: [ConnectionSource]) {
        self.sources = sources
        self.activeSource = sources.first!
    }

    func start() {
        activeSource.onUpdate = { [weak self] connections in
            self?.onUpdate?(connections)
        }
        activeSource.start()
    }

    func stop() {
        activeSource.stop()
    }

    func switchTo(sourceNamed name: String) {
        guard let newSource = sources.first(where: { $0.displayName == name }),
              newSource.displayName != activeSource.displayName else {
            return
        }

        activeSource.stop()
        activeSource.onUpdate = nil

        activeSource = newSource
        activeSource.onUpdate = { [weak self] connections in
            self?.onUpdate?(connections)
        }
        activeSource.start()
    }

    var availableSources: [String] {
        sources.map { $0.displayName }
    }
}
