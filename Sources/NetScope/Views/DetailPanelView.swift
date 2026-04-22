import SwiftUI
import AppKit

struct DetailPanelView: View {
    @EnvironmentObject var connectionStore: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @State private var selectedConnectionID: String? = nil

    var filteredConnections: [Connection] {
        return connectionStore.filteredConnections
    }

    var processName: String {
        return connectionStore.selectedProcess ?? "All Processes"
    }

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
                    label: "↓ Received",
                    value: formatBytes(totalIn),
                    color: Color(NSColor.systemBlue)
                )
                TrafficCard(
                    label: "↑ Sent",
                    value: formatBytes(totalOut),
                    color: Color(NSColor.systemRed)
                )
            }
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

struct ConnectionListSection: View {
    @Binding var selectedConnectionID: String?
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connections Detail")
                .font(.system(size: 12, weight: .semibold))

            ForEach(store.filteredConnections) { conn in
                VStack(spacing: 0) {
                    ConnectionRow(
                        connection: conn,
                        color: store.colorForProcess(conn.processName),
                        isExpanded: selectedConnectionID == conn.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedConnectionID == conn.id {
                            selectedConnectionID = nil
                            tracerouteStore.clear()
                        } else {
                            selectedConnectionID = conn.id
                            tracerouteStore.startTraceroute(for: conn)
                        }
                    }

                    if selectedConnectionID == conn.id {
                        TracerouteView()
                            .environmentObject(tracerouteStore)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                                    removal: .opacity))
                    }
                }
            }
        }
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
