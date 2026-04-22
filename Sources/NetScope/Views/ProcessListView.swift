import SwiftUI
import AppKit

struct ProcessListView: View {
    @EnvironmentObject var store: ConnectionStore
    @State private var searchText = ""

    var filteredProcesses: [(name: String, pid: Int, count: Int, colorIndex: Int)] {
        let processes = store.processes
        if searchText.isEmpty {
            return processes
        }
        return processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter processes…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // "All" row
            Button(action: { store.selectProcess(nil) }) {
                let count = store.totalConnectionCount
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 18))
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("All Processes")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(count) connections")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(store.selectedProcess == nil ? Color.accentColor.opacity(0.15) : Color.clear)

            Divider().padding(.horizontal, 10)

            // Process list
            List {
                ForEach(filteredProcesses, id: \.name) { proc in
                    Button(action: { store.selectProcess(proc.name) }) {
                        ProcessRow(
                            name: proc.name,
                            count: proc.count,
                            color: store.processColorsList[proc.colorIndex % store.processColorsList.count],
                            isSelected: store.selectedProcess == proc.name
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ProcessRow: View {
    let name: String
    let count: Int
    let color: String
    let isSelected: Bool

    @EnvironmentObject var store: ConnectionStore

    var trafficInfo: (in: Int64, out: Int64) {
        let processConnections = store.connections.filter { $0.processName == name }
        let totalIn = processConnections.reduce(0) { $0 + $1.bytesIn }
        let totalOut = processConnections.reduce(0) { $0 + $1.bytesOut }
        return (totalIn, totalOut)
    }

    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(processName: name)
                .frame(width: 28, height: 28)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("↓\(formatCompactRate(trafficInfo.in))")
                    Text("↑\(formatCompactRate(trafficInfo.out))")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(nsColor))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color(nsColor).opacity(0.15) : Color.clear)
        .overlay(
            isSelected ? Rectangle()
                .frame(width: 3)
                .foregroundColor(Color(nsColor))
                .offset(x: -1)
            : nil,
            alignment: .leading
        )
    }

    private func formatCompactRate(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 0.1 { return "0 B/s" }
        else if kb < 1024.0 { return String(format: "%.0f KB/s", kb) }
        else { return String(format: "%.1f MB/s", kb / 1024.0) }
    }
}

struct AppIconView: NSViewRepresentable {
    let processName: String

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = iconForProcess(processName)
    }

    private func iconForProcess(_ name: String) -> NSImage? {
        let runningApps = NSWorkspace.shared.runningApplications

        if let app = runningApps.first(where: {
            $0.localizedName?.lowercased() == name.lowercased()
            || $0.bundleIdentifier?.lowercased() == name.lowercased()
        }) {
            return app.icon
        }

        if let app = runningApps.first(where: {
            let locName = $0.localizedName?.lowercased() ?? ""
            let bundleId = $0.bundleIdentifier?.lowercased() ?? ""
            let lowerName = name.lowercased()
            return bundleId.contains(lowerName) || lowerName.contains(bundleId) || lowerName.contains(locName)
        }) {
            return app.icon
        }

        if name.lowercased().contains("apple") || name.lowercased().contains("kernel") {
            return NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        }

        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
    }
}
