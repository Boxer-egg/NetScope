import Testing
@testable import NetScope

struct TracerouteRunnerTests {

    @Test func parseNormalHop() async throws {
        let line = " 3  142.251.49.1  14.234 ms"
        let hop = TracerouteRunner.parseLine(line)
        #expect(hop != nil)
        #expect(hop?.id == 3)
        #expect(hop?.ip == "142.251.49.1")
        #expect(hop?.rtt == 14.234)
        #expect(hop?.isTimeout == false)
    }

    @Test func parseTimeoutHop() async throws {
        let line = " 3  * * *"
        let hop = TracerouteRunner.parseLine(line)
        #expect(hop != nil)
        #expect(hop?.id == 3)
        #expect(hop?.ip == nil)
        #expect(hop?.rtt == nil)
        #expect(hop?.isTimeout == true)
    }

    @Test func parseEmptyLine() async throws {
        let hop = TracerouteRunner.parseLine("")
        #expect(hop == nil)
    }
}
