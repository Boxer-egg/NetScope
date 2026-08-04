import XCTest
@testable import NetScope

final class ConnectionProviderTests: XCTestCase {

    class MockSource: ConnectionSource {
        var onUpdate: (([Connection]) -> Void)?
        var onFailure: ((String) -> Void)?
        var pollInterval: TimeInterval = 1.0
        var displayName: String
        var started = false
        var stopped = false

        init(name: String) {
            self.displayName = name
        }

        func start() {
            started = true
        }

        func stop() {
            stopped = true
        }
    }

    func testProviderStartsFirstSource() {
        let source1 = MockSource(name: "Source1")
        let source2 = MockSource(name: "Source2")
        let provider = ConnectionProvider(sources: [source1, source2])

        provider.start()

        XCTAssertTrue(source1.started)
        XCTAssertFalse(source2.started)
    }

    func testProviderSwitchSource() {
        let source1 = MockSource(name: "Source1")
        let source2 = MockSource(name: "Source2")
        let provider = ConnectionProvider(sources: [source1, source2])

        provider.start()
        provider.switchTo(sourceNamed: "Source2")

        XCTAssertTrue(source1.stopped)
        XCTAssertTrue(source2.started)
    }

    func testProviderSwitchToSameSourceIsNoOp() {
        let source1 = MockSource(name: "Source1")
        let source2 = MockSource(name: "Source2")
        let provider = ConnectionProvider(sources: [source1, source2])

        provider.start()
        provider.switchTo(sourceNamed: "Source1")

        XCTAssertFalse(source1.stopped)
        XCTAssertFalse(source2.started)
    }

    func testProviderAvailableSources() {
        let source1 = MockSource(name: "Source1")
        let source2 = MockSource(name: "Source2")
        let provider = ConnectionProvider(sources: [source1, source2])

        XCTAssertEqual(provider.availableSources, ["Source1", "Source2"])
    }

    func testProviderPropagatesUpdates() {
        let source1 = MockSource(name: "Source1")
        let provider = ConnectionProvider(sources: [source1])

        var receivedConnections: [Connection]?
        provider.onUpdate = { connections in
            receivedConnections = connections
        }

        provider.start()

        let conn = Connection(
            pid: 123, processName: "Test", localPort: 5000,
            remoteIP: "1.2.3.4", remotePort: 443, proto: "TCP",
            state: "Established", bytesIn: 1000, bytesOut: 500
        )
        source1.onUpdate?([conn])

        XCTAssertEqual(receivedConnections?.count, 1)
        XCTAssertEqual(receivedConnections?.first?.remoteIP, "1.2.3.4")
    }

    func testProviderPropagatesFailures() {
        let source1 = MockSource(name: "Source1")
        let provider = ConnectionProvider(sources: [source1])

        var receivedReason: String?
        provider.onFailure = { reason in
            receivedReason = reason
        }

        provider.start()
        source1.onFailure?("TestFailure")

        XCTAssertEqual(receivedReason, "TestFailure")
    }

    func testProviderSetsPollIntervalOnAllSources() {
        let source1 = MockSource(name: "Source1")
        let source2 = MockSource(name: "Source2")
        let provider = ConnectionProvider(sources: [source1, source2])

        provider.setPollInterval(5.0)

        XCTAssertEqual(source1.pollInterval, 5.0)
        XCTAssertEqual(source2.pollInterval, 5.0)
    }
}
