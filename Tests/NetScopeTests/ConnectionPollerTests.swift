import Testing
@testable import NetScope

struct ConnectionPollerTests {

    @Test func parseNormalTCPEstablished() async throws {
        let line = "Safari  1234 user  23u  IPv4 0x123  TCP 192.168.1.5:52341->142.250.80.46:443 (ESTABLISHED)"
        let output = parseLsof(line)
        #expect(output.count == 1)
        #expect(output[0].processName == "Safari")
        #expect(output[0].pid == 1234)
        #expect(output[0].remoteIP == "142.250.80.46")
        #expect(output[0].remotePort == 443)
        #expect(output[0].localPort == 52341)
        #expect(output[0].proto == "TCP")
    }

    @Test func parseUDP() async throws {
        let line = "mDNSRes  432 user   8u  IPv4 0x456  UDP *:5353"
        let output = parseLsof(line)
        #expect(output.count == 0) // UDP without remote address should be filtered
    }

    @Test func parseIPv6() async throws {
        let line = "Safari  1234 user  24u  IPv6 0x789  TCP [::1]:52342->[2404:6800::443]:443 (ESTABLISHED)"
        let output = parseLsof(line)
        #expect(output.count == 1)
        #expect(output[0].remoteIP == "2404:6800::443")
        #expect(output[0].remotePort == 443)
    }

    @Test func filterPrivateIPs() async throws {
        let tests: [(String, Bool)] = [
            ("127.0.0.1", true),
            ("10.0.0.1", true),
            ("192.168.1.1", true),
            ("172.16.0.1", true),
            ("172.31.255.255", true),
            ("172.32.0.1", false),
            ("8.8.8.8", false),
            ("1.1.1.1", false),
        ]
        for (ip, expected) in tests {
            #expect(isPrivateIP(ip) == expected, "IP: \(ip)")
        }
    }

    @Test func parseTruncatedProcessName() async throws {
        let line = "com.apple.We 5612 user  12u  IPv4 0xabc  TCP 192.168.1.5:53201->17.57.144.1:443 (ESTABLISHED)"
        let output = parseLsof(line)
        #expect(output.count == 1)
        #expect(output[0].processName == "com.apple.We")
        #expect(output[0].remoteIP == "17.57.144.1")
    }
}
