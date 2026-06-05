import XCTest
@testable import NetScope

final class NettopConnectionSourceExtraTests: XCTestCase {

    func testFiltersWildcardConnections() {
        let source = NettopConnectionSource()
        let output = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        18:18:38.329546,mDNSResponder.272,,,67044191,20822887,0,0,0,,,,,,,,,,,,
        18:18:38.329217,udp6 *.5353<->*.*,en0,,14431855,8190886,,,,,786896,,CTL,,,,,,,so,
        18:18:38.329198,udp4 *:5353<->*:*,en0,,70116364,13929787,,,,,786896,,CTL,,,,,,,so,
        18:18:38.329237,udp4 192.168.3.37:9993<->8.8.8.8:53,en0,,17411503,19446381,0,0,0,,,,,,,,,,,so,
        """

        let conns = source.parseNettopOutput(output)
        XCTAssertEqual(conns.count, 1)
        XCTAssertEqual(conns.first?.remoteIP, "8.8.8.8")
        XCTAssertEqual(conns.first?.remotePort, 53)
    }

    func testFiltersEmptyRemoteIP() {
        let source = NettopConnectionSource()
        let output = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        18:18:38.329546,test.123,,,100,200,0,0,0,,,,,,,,,,,,
        18:18:38.329237,udp4 192.168.1.1:12345<->:0,en0,,0,0,0,0,0,,,,,,,,,,,so,
        """

        let conns = source.parseNettopOutput(output)
        // Empty remote IP with port 0 should be filtered
        XCTAssertEqual(conns.count, 0)
    }

    func testParseAddressIPv4() {
        let source = NettopConnectionSource()

        // Test parsing via reflection - the parseAddress is private,
        // but we can verify through connection output
        let output = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        18:18:38.329546,test.123,,,100,200,0,0,0,,,,,,,,,,,,
        18:18:38.329237,tcp4 192.168.1.1:12345<->8.8.8.8:53,en0,Established,1000,2000,0,0,0,,,,,,,,,,,,
        """

        let conns = source.parseNettopOutput(output)
        XCTAssertEqual(conns.count, 1)
        XCTAssertEqual(conns.first?.remoteIP, "8.8.8.8")
        XCTAssertEqual(conns.first?.remotePort, 53)
        XCTAssertEqual(conns.first?.localPort, 12345)
    }

    func testParseAddressIPv6() {
        let source = NettopConnectionSource()
        let output = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        18:18:38.329546,test.123,,,100,200,0,0,0,,,,,,,,,,,,
        18:18:38.329237,tcp6 [2001:db8::1]:12345<->[2606:4700::1111]:443,en0,Established,1000,2000,0,0,0,,,,,,,,,,,,
        """

        let conns = source.parseNettopOutput(output)
        XCTAssertEqual(conns.count, 1)
        XCTAssertEqual(conns.first?.remoteIP, "2606:4700::1111")
        XCTAssertEqual(conns.first?.remotePort, 443)
    }

    func testMultipleConnectionsSameProcess() {
        let source = NettopConnectionSource()
        let output = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        18:18:38.329546,Chrome.123,,,100,200,0,0,0,,,,,,,,,,,,
        18:18:38.329237,tcp4 192.168.1.1:50001<->1.2.3.4:443,en0,Established,1000,2000,0,0,0,,,,,,,,,,,,
        18:18:38.329238,tcp4 192.168.1.1:50002<->5.6.7.8:443,en0,Established,3000,4000,0,0,0,,,,,,,,,,,,
        """

        let conns = source.parseNettopOutput(output)
        XCTAssertEqual(conns.count, 2)
        XCTAssertEqual(conns[0].processName, "Chrome")
        XCTAssertEqual(conns[1].processName, "Chrome")
        XCTAssertEqual(conns[0].remoteIP, "1.2.3.4")
        XCTAssertEqual(conns[1].remoteIP, "5.6.7.8")
    }
}
