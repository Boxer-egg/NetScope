import SwiftUI
import AppKit

struct DetailPanelView: View {
    @EnvironmentObject var connectionStore: ConnectionStore
    @EnvironmentObject var tracerouteStore: TracerouteStore
    @State private var selectedConnectionID: String? = nil

    var filteredConnections: [Connection] {
        connectionStore.filteredConnections
    }

    var processName: String {
        connectionStore.selectedProcess ?? "All Processes"
    }

    var totalConnections: Int {
        connectionStore.selectedProcess == nil
            ? connectionStore.totalConnectionCount
            : filteredConnections.count
    }

    var uniqueCountries: Int {
        Set(filteredConnections.compactMap { $0.geoInfo?.country }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                HStack(spacing: 8) {
                    AppIconView(processName: processName)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(processName)
                            .font(.system(size: 13, weight: .medium))
                        Text("\(totalConnections) connections · \(uniqueCountries) countries")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Connection list
            List {
                ForEach(filteredConnections) { conn in
                    ConnectionRow(
                        connection: conn,
                        color: connectionStore.colorForProcess(conn.processName),
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
            .listStyle(.plain)
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
                    Text("\(geo.city ?? geo.country)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 4) {
                Text(":\(connection.remotePort)")
                Text("·")
                Text(connection.proto)
                Text("·")
                Text(connection.state)
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .padding(.leading, 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isExpanded ? Color(nsColor).opacity(0.08) : Color.clear)
    }
}
