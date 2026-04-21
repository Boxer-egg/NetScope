import SwiftUI
import AppKit

struct ProcessListView: View {
    @EnvironmentObject var store: ConnectionStore
    @State private var searchText = ""

    var filteredProcesses: [(name: String, pid: Int, count: Int, colorIndex: Int)] {
        if searchText.isEmpty {
            return store.processes
        }
        return store.processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 18))
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("All Processes")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(store.totalConnectionCount) connections")
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
                            pid: proc.pid,
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
            .scrollContentBackground(.hidden) // Important for macOS 13+
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ProcessRow: View {
    let name: String
    let pid: Int
    let count: Int
    let color: String
    let isSelected: Bool

    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            AppIconView(processName: name)
                .frame(width: 28, height: 28)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("PID: \(pid)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
        // Try to find running application by name
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: {
            $0.localizedName?.lowercased().contains(name.lowercased()) == true
            || $0.bundleIdentifier?.lowercased().contains(name.lowercased()) == true
        }) {
            return app.icon
        }

        // Fallback: generic gear icon
        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
    }
}
