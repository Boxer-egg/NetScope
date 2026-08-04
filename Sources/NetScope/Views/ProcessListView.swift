import SwiftUI
import AppKit

struct ProcessListView: View {
    @EnvironmentObject var store: ConnectionStore
    @State private var searchText = ""
    @State private var expandedProcesses: Set<String> = []

    var filteredProcesses: [(name: String, pid: Int, count: Int, colorIndex: Int)] {
        let processes = store.processes
        if searchText.isEmpty {
            return processes
        }
        return processes.filter { proc in
            if proc.name.localizedCaseInsensitiveContains(searchText) { return true }
            return (store.processConnections[proc.name] ?? []).contains {
                $0.remoteIP.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func toggleExpanded(_ name: String) {
        if expandedProcesses.contains(name) {
            expandedProcesses.remove(name)
        } else {
            expandedProcesses.insert(name)
        }
    }

    func connections(for processName: String) -> [Connection] {
        store.processConnections[processName] ?? []
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
            if filteredProcesses.isEmpty {
                Spacer()
                Text(searchText.isEmpty
                     ? String(localized: "No active connections", bundle: .module)
                     : String(localized: "No matching processes", bundle: .module))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(filteredProcesses, id: \.name) { proc in
                        VStack(spacing: 0) {
                            ProcessRow(
                                name: proc.name,
                                count: proc.count,
                                color: store.processColorsList[proc.colorIndex % store.processColorsList.count],
                                isSelected: store.selectedProcess == proc.name,
                                isExpanded: expandedProcesses.contains(proc.name),
                                onToggleExpand: { toggleExpanded(proc.name) },
                                onSelect: { store.selectProcess(proc.name) }
                            )

                            if expandedProcesses.contains(proc.name) {
                                let conns = connections(for: proc.name)
                                ForEach(conns) { conn in
                                    ProcessConnectionRow(connection: conn)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ProcessRow: View {
    let name: String
    let count: Int
    let color: String
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void

    @EnvironmentObject var store: ConnectionStore

    var trafficInfo: (in: Int64, out: Int64) {
        if let t = store.processTraffic[name] { return (t.bytesIn, t.bytesOut) }
        return (0, 0)
    }

    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }

    var body: some View {
        HStack(spacing: 8) {
            // Expand/collapse chevron
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 28)
            }
            .buttonStyle(.plain)

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
        .onTapGesture {
            onSelect()
        }
    }

    private func formatCompactRate(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 0.1 { return "0 B/s" }
        else if kb < 1024.0 { return String(format: "%.0f KB/s", kb) }
        else { return String(format: "%.1f MB/s", kb / 1024.0) }
    }
}

struct ProcessConnectionRow: View {
    let connection: Connection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(connection.remoteIP)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            Text("\(connection.remotePort)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .padding(.leading, 36)
    }
}

struct AppIconView: NSViewRepresentable {
    let processName: String

    private static var iconCache: [String: NSImage] = [:]

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
        if let cached = AppIconView.iconCache[name] { return cached }

        let runningApps = NSWorkspace.shared.runningApplications
        let lowerName = name.lowercased()

        let icon: NSImage?
        if let app = runningApps.first(where: {
            $0.localizedName?.lowercased() == lowerName
            || $0.bundleIdentifier?.lowercased() == lowerName
        }) {
            icon = app.icon
        } else if let app = runningApps.first(where: {
            let locName = $0.localizedName?.lowercased() ?? ""
            let bundleId = $0.bundleIdentifier?.lowercased() ?? ""
            return bundleId.contains(lowerName) || lowerName.contains(bundleId) || lowerName.contains(locName)
        }) {
            icon = app.icon
        } else if lowerName.contains("apple") || lowerName.contains("kernel") {
            icon = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        } else {
            icon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        }

        AppIconView.iconCache[name] = icon
        return icon
    }
}
