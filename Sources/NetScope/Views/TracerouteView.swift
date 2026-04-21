import SwiftUI

struct TracerouteView: View {
    @EnvironmentObject var store: TracerouteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Traceroute to \(store.targetIP)")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if store.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else if store.isComplete {
                    Text("Done · \(store.totalHops) hops · \(formatRTT(store.totalRTT))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

            Divider()

            // Hop list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.hops) { hop in
                        HopRow(hop: hop)
                    }
                }
            }
            .frame(minHeight: 100, maxHeight: 300)

            Divider()

            // Toolbar
            HStack {
                Button("Re-run") {
                    if store.selectedConnectionID != nil {
                        // Need to find connection and restart
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))

                Spacer()

                if store.isRunning {
                    Button("Stop") {
                        store.cancel()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.15))
    }

    private func formatRTT(_ rtt: Double?) -> String {
        guard let rtt = rtt else { return "N/A" }
        return String(format: "%.1f ms", rtt)
    }
}

struct HopRow: View {
    let hop: TracerouteHop

    var statusColor: Color {
        guard let rtt = hop.rtt else { return .gray }
        switch rtt {
        case ..<50: return .green
        case 50..<150: return .yellow
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Hop number
            Text("\(hop.id)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                if hop.isTimeout {
                    Text("* * * timeout")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                } else if let ip = hop.ip {
                    Text(ip)
                        .font(.system(size: 12, design: .monospaced))

                    if let geo = hop.geoInfo {
                        Text("\(geo.city ?? "") · \(geo.country)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let rtt = hop.rtt {
                Text(String(format: "%.1f ms", rtt))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
