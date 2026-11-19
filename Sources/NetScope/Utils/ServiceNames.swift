import Foundation

enum ServiceNames {
    private static let byPort: [Int: String] = [
        20: "FTP-DATA", 21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP",
        53: "DNS", 67: "DHCP", 68: "DHCP", 69: "TFTP", 80: "HTTP",
        88: "Kerberos", 110: "POP3", 111: "RPC", 123: "NTP", 135: "MSRPC",
        137: "NetBIOS", 138: "NetBIOS", 139: "NetBIOS", 143: "IMAP",
        161: "SNMP", 179: "BGP", 389: "LDAP", 443: "HTTPS", 445: "SMB",
        465: "SMTPS", 500: "IKE", 515: "LPD", 587: "SMTP", 593: "RPC",
        636: "LDAPS", 853: "DoH", 873: "rsync", 902: "VMware", 989: "FTPS",
        990: "FTPS", 993: "IMAPS", 995: "POP3S", 1080: "SOCKS", 1194: "OpenVPN",
        1433: "MSSQL", 1521: "Oracle", 1701: "L2TP", 1723: "PPTP",
        1883: "MQTT", 2049: "NFS", 2375: "Docker", 2376: "Docker",
        3000: "Dev-Server", 3306: "MySQL", 3389: "RDP", 3689: "iTunes",
        4070: "AirPlay-RAOP", 4443: "HTTPS-ALT", 4500: "IPsec", 5000: "UPnP",
        5060: "SIP", 5061: "SIP-TLS", 5222: "XMPP", 5223: "APN", 5353: "mDNS",
        5432: "PostgreSQL", 5672: "AMQP", 5900: "VNC", 5985: "WinRM",
        6379: "Redis", 6443: "Kubernetes", 6667: "IRC", 7000: "AirPlay",
        8000: "HTTP-ALT", 8008: "HTTP-ALT", 8080: "HTTP-ALT", 8140: "Puppet",
        8443: "HTTPS-ALT", 8883: "MQTT-TLS", 9000: "HTTP-ALT", 9092: "Kafka",
        9100: "Printer", 9200: "Elasticsearch", 9300: "Elasticsearch",
        11211: "Memcached", 27017: "MongoDB", 27018: "MongoDB", 32400: "Plex",
        33434: "Traceroute"
    ]

    /// Returns the well-known service name for a remote endpoint, if any.
    static func serviceName(port: Int, proto: String) -> String? {
        if proto.uppercased() == "UDP", port == 443 {
            return "QUIC"
        }
        return byPort[port]
    }
}
