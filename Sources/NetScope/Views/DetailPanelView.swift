import SwiftUI
import AppKit

struct DetailPanelView: View {
    @EnvironmentObject var connectionStore: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @State private var selectedConnectionID: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Summary Section
                    SummarySection()
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    Divider().padding(.horizontal, 12)

                    // Connections State Section
                    ConnectionsStateSection()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Divider().padding(.horizontal, 12)

                    // Top Processes Section (only in global view)
                    if connectionStore.selectedProcess == nil {
                        TopProcessesSection()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                        Divider().padding(.horizontal, 12)
                    }

                    // Top Hosts Section
                    TopHostsSection()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Divider().padding(.horizontal, 12)

                    // Connection Detail List
                    ConnectionListSection(
                        selectedConnectionID: $selectedConnectionID
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Summary Section

struct SummarySection: View {
    @EnvironmentObject var store: ConnectionStore

    var processCount: Int {
        if store.selectedProcess != nil {
            return 1
        }
        return store.uniqueProcessCount
    }

    var hostCount: Int {
        let conns = store.filteredConnections
        return Set(conns.map { $0.remoteIP }).count
    }

    var totalIn: Int64 {
        store.filteredConnections.reduce(0) { $0 + $1.bytesIn }
    }

    var totalOut: Int64 {
        store.filteredConnections.reduce(0) { $0 + $1.bytesOut }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AppIconView(processName: store.selectedProcess ?? "All Processes")
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedProcess ?? "Summary")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(processCount) processes · \(hostCount) hosts")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                TrafficCard(
                    label: String(localized: "↓ Received /s", bundle: .module),
                    value: Connection.formatRate(totalIn),
                    color: Color(NSColor.systemBlue)
                )
                TrafficCard(
                    label: String(localized: "↑ Sent /s", bundle: .module),
                    value: Connection.formatRate(totalOut),
                    color: Color(NSColor.systemRed)
                )
            }

            Text(String(format: String(localized: "Since launch: ↓ %@ · ↑ %@", bundle: .module),
                        formatBytes(store.sessionBytesIn), formatBytes(store.sessionBytesOut)))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1 { return "\(bytes) B" }
        let mb = kb / 1024.0
        if mb < 1 { return String(format: "%.1f KB", kb) }
        let gb = mb / 1024.0
        if gb < 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", gb)
    }
}

struct TrafficCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Connections State Section

struct ConnectionsStateSection: View {
    @EnvironmentObject var store: ConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connections")
                .font(.system(size: 12, weight: .semibold))

            let states = store.filteredConnections
                .filter { $0.state != "Unknown" }
                .reduce(into: [:]) { counts, conn in counts[conn.state, default: 0] += 1 }

            if states.isEmpty {
                Text(String(localized: "No active connections", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(states.sorted { $0.value > $1.value }, id: \.key) { state, count in
                    HStack {
                        Circle()
                            .fill(stateColor(state))
                            .frame(width: 6, height: 6)
                        Text(state)
                            .font(.system(size: 11))
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
            }
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "Established": return .green
        case "Listen": return .blue
        case "SynSent", "SynReceived": return .yellow
        case "FinWait1", "FinWait2", "CloseWait", "Closing", "LastAck", "TimeWait": return .orange
        case "Closed": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Top Processes Section

struct TopProcessesSection: View {
    @EnvironmentObject var store: ConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.system(size: 12, weight: .semibold))

            ForEach(store.topProcesses.prefix(5), id: \.name) { proc in
                HStack(spacing: 8) {
                    AppIconView(processName: proc.name)
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(proc.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(formatBytes(proc.bytesIn) + " ↓")
                            Text("·")
                            Text(formatBytes(proc.bytesOut) + " ↑")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1 { return "\(bytes) B" }
        let mb = kb / 1024.0
        if mb < 1 { return String(format: "%.0f KB", kb) }
        let gb = mb / 1024.0
        if gb < 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Top Hosts Section

struct TopHostsSection: View {
    @EnvironmentObject var store: ConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Hosts")
                .font(.system(size: 12, weight: .semibold))

            ForEach(store.topHosts.prefix(5), id: \.host) { host in
                HStack {
                    Text(host.host)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text(formatBytes(host.bytesIn + host.bytesOut))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .contextMenu {
                    Button(String(localized: "Copy IP", bundle: .module)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(host.host, forType: .string)
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1 { return "\(bytes) B" }
        let mb = kb / 1024.0
        if mb < 1 { return String(format: "%.0f KB", kb) }
        let gb = mb / 1024.0
        if gb < 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Connection List Section

enum ConnectionSortOrder: String, CaseIterable {
    case traffic, host, port, state

    var displayName: String {
        switch self {
        case .traffic: return String(localized: "Sort: Traffic", bundle: .module)
        case .host: return String(localized: "Sort: Host", bundle: .module)
        case .port: return String(localized: "Sort: Port", bundle: .module)
        case .state: return String(localized: "Sort: State", bundle: .module)
        }
    }
}

struct ConnectionListSection: View {
    @Binding var selectedConnectionID: String?
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @State private var sortOrder: ConnectionSortOrder = .traffic
    @State private var exportError: String? = nil

    var sortedConnections: [Connection] {
        let conns = store.filteredConnections
        switch sortOrder {
        case .traffic:
            return conns.sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }
        case .host:
            return conns.sorted { $0.remoteIP < $1.remoteIP }
        case .port:
            return conns.sorted { $0.remotePort < $1.remotePort }
        case .state:
            return conns.sorted { $0.state < $1.state }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connections Detail")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Menu {
                    ForEach(ConnectionSortOrder.allCases, id: \.self) { order in
                        Button(order.displayName) { sortOrder = order }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20)
                .help(String(localized: "Sort connections", bundle: .module))

                Button(action: exportCSV) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Export connections as CSV", bundle: .module))
                .disabled(store.filteredConnections.isEmpty)
            }

            if store.isLoading && store.connections.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Loading connections…", bundle: .module))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if store.filteredConnections.isEmpty {
                Text(String(localized: "No active connections", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedConnections) { conn in
                        connectionItem(for: conn)
                    }
                }
            }

            if let error = exportError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private func connectionItem(for conn: Connection) -> some View {
        VStack(spacing: 0) {
            ConnectionRow(
                connection: conn,
                color: store.colorForProcess(conn.processName),
                isExpanded: selectedConnectionID == conn.id
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if selectedConnectionID == conn.id {
                        selectedConnectionID = nil
                    } else {
                        selectedConnectionID = conn.id
                    }
                }
            }
            .contextMenu {
                Button(String(localized: "Copy IP", bundle: .module)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(conn.remoteIP, forType: .string)
                }
                Button(String(localized: "Copy Address", bundle: .module)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(conn.remoteIP):\(conn.remotePort)", forType: .string)
                }
            }

            if selectedConnectionID == conn.id {
                ConnectionDetailView(connection: conn)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                            removal: .opacity))

                if tracerouteStore.selectedConnectionID == conn.id {
                    TracerouteView()
                        .environmentObject(tracerouteStore)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                                removal: .opacity))
                }
            }
        }
    }

    private func exportCSV() {
        exportError = nil
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "netscope-connections.csv"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var lines = ["process,pid,proto,local_port,remote_ip,remote_port,state,bytes_in_interval,bytes_out_interval,country,city"]
        let conns = store.filteredConnections
        for conn in conns {
            let country = conn.geoInfo?.country ?? ""
            let city = conn.geoInfo?.city ?? ""
            let row = [
                Self.csvEscape(conn.processName),
                "\(conn.pid)",
                conn.proto,
                "\(conn.localPort)",
                conn.remoteIP,
                "\(conn.remotePort)",
                conn.state,
                "\(conn.bytesIn)",
                "\(conn.bytesOut)",
                Self.csvEscape(country),
                Self.csvEscape(city)
            ].joined(separator: ",")
            lines.append(row)
        }

        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = String(format: String(localized: "Export failed: %@", bundle: .module), error.localizedDescription)
        }
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// MARK: - Connection Detail (expanded)

struct ConnectionDetailView: View {
    let connection: Connection
    @EnvironmentObject var tracerouteStore: TracerouteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            detailRow(String(localized: "Process", bundle: .module), "\(connection.processName) (\(connection.pid))")
            detailRow(String(localized: "Local Port", bundle: .module), "\(connection.localPort)")
            if let geo = connection.geoInfo, let asn = geo.asn, !asn.isEmpty {
                detailRow(String(localized: "ASN", bundle: .module), asn)
            }
            detailRow(String(localized: "First Seen", bundle: .module), Self.timeFormatter.string(from: connection.firstSeen))
            detailRow(String(localized: "Total In / Out", bundle: .module),
                      "\(Self.formatBytes(connection.rawBytesIn)) / \(Self.formatBytes(connection.rawBytesOut))")

            HStack {
                Spacer()
                Button(String(localized: "Run Traceroute", bundle: .module)) {
                    tracerouteStore.startTraceroute(for: connection)
                }
                .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .font(.system(size: 10))
        .padding(.leading, 14)
        .padding(.vertical, 4)
        .foregroundColor(.secondary)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1 { return "\(bytes) B" }
        let mb = kb / 1024.0
        if mb < 1 { return String(format: "%.0f KB", kb) }
        let gb = mb / 1024.0
        if gb < 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.1f GB", gb)
    }
}

struct ConnectionRow: View {
    let connection: Connection
    let color: String
    let isExpanded: Bool

    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(nsColor))
                    .frame(width: 6, height: 6)

                Text(connection.remoteIP)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Spacer()

                if let geo = connection.geoInfo {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(geo.city ?? "") \(geo.country)")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(String(format: "%.2f, %.2f", geo.latitude, geo.longitude))
                            .font(.system(size: 9, weight: .light))
                            .foregroundColor(.secondary)
                    }
                } else if isPrivateIP(connection.remoteIP) {
                    Text("Private / Local")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                } else if connection.geoLookupFailed {
                    Text("Location unavailable")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                } else {
                    Text("Resolving...")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(":\(connection.remotePort)")
                    Text("•")
                    Text(connection.proto)
                    Text("•")
                    Text(connection.state)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                        Text(Connection.formatRate(connection.bytesIn))
                        Image(systemName: "arrow.up")
                        Text(Connection.formatRate(connection.bytesOut))
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }
            .padding(.leading, 14)
        }
        .padding(.vertical, 6)
        .background(isExpanded ? Color(nsColor).opacity(0.08) : Color.clear)
        .cornerRadius(4)
    }
}
