import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var appStore: AppStore
    @EnvironmentObject var store: ConnectionStore

    var onOpenWindow: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
                Text("NetScope")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if appStore.isPaused {
                    Text(String(localized: "Paused", bundle: .module))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            HStack(spacing: 12) {
                Label("\(store.totalConnectionCount)", systemImage: "link")
                Label(Connection.formatRate(store.totalBytesIn), systemImage: "arrow.down")
                Label(Connection.formatRate(store.totalBytesOut), systemImage: "arrow.up")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if store.topProcesses.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(String(localized: "No active connections", bundle: .module))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(store.topProcesses.prefix(5), id: \.name) { proc in
                        HStack(spacing: 8) {
                            AppIconView(processName: proc.name)
                                .frame(width: 18, height: 18)
                                .cornerRadius(4)
                            Text(proc.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text("↓\(Connection.formatRate(proc.bytesIn))")
                                .foregroundColor(.secondary)
                            Text("↑\(Connection.formatRate(proc.bytesOut))")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 10))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.vertical, 4)
                Spacer()
            }

            Divider()

            HStack {
                Button(String(localized: "Open NetScope", bundle: .module)) { onOpenWindow() }
                    .controlSize(.small)

                Spacer()

                Button(appStore.isPaused
                       ? String(localized: "Resume", bundle: .module)
                       : String(localized: "Pause", bundle: .module)) {
                    appStore.setPaused(!appStore.isPaused)
                }
                .controlSize(.small)

                Button(String(localized: "Quit", bundle: .module)) { onQuit() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300, height: 340)
    }
}
