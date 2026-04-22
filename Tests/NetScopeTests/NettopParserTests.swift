import XCTest
@testable import NetScope

final class NettopParserTests: XCTestCase {

    let mockNettopOutput = """
time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
18:18:38.329546,mDNSResponder.272,,,67044191,20822887,0,0,0,,,,,,,,,,,,
18:18:38.329217,udp6 *.5353<->*.*,en0,,14431855,8190886,,,,,786896,,CTL,,,,,,,so,
18:18:38.329198,udp4 *:5353<->*:*,en0,,70116364,13929787,,,,,786896,,CTL,,,,,,,so,
18:18:38.329558,zerotier-one.284,,,80254563,60708540,0,0,0,,,,,,,,,,,,
18:18:38.329277,udp4 192.168.3.37:62457<->*:*,en0,,32286682,19508471,0,0,0,,,,,,,,,,,so,
18:18:38.329594,Microsoft Edge .772,,,13530917,11022,0,0,0,,,,,,,,,,,,
18:18:38.329510,udp6 *.5353<->*.*,utun5,,974982,1002,,,,,786896,,BE,,,,,,,so,
18:18:38.329237,udp4 192.168.3.37:9993<->8.8.8.8:53,en0,,17411503,19446381,0,0,0,,,,,,,,,,,so,
18:18:38.329500,tcp4 192.168.3.37:56241<->17.57.145.55:5223,en0,Established,27201,31090,0,3590,0,108.53 ms,131072,31872,RD,-,cubic,-,-,-,-,ch,
"""

    func testParserIdentifiesProcesses() {
        let poller = ConnectionPoller()
        let conns = poller.parseNettopRobust(mockNettopOutput)

        // 验证是否抓到了 Microsoft Edge
        let edgeConns = conns.filter { $0.processName == "Microsoft Edge" }
        XCTAssertFalse(edgeConns.isEmpty, "应该解析出 Microsoft Edge 的连接")

        // 验证公网 IP 连线 (8.8.8.8)
        let googleDns = conns.filter { $0.remoteIP == "8.8.8.8" }
        XCTAssertFalse(googleDns.isEmpty, "应该解析出 8.8.8.8 的连接")

        // 验证 17.57.145.55 被正确解析
        let appleIP = conns.filter { $0.remoteIP == "17.57.145.55" }
        XCTAssertFalse(appleIP.isEmpty, "应该解析出 17.57.145.55 的连接")

        // 验证星号/通配符连接被正确解析（不计入正常连接统计）
        let wildcardConns = conns.filter { $0.remoteIP == "*" || $0.remoteIP == "*.*" }
        XCTAssertGreaterThan(wildcardConns.count, 0, "应该解析出通配符连接")

        print("✅ 解析成功！共抓到 \(conns.count) 条连接。")
    }
}
