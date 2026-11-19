import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject private var store = AppStore.shared
    @State private var leftPanelVisible = true
    @State private var rightPanelVisible = true
    @State private var selectedSource: String = ""
    @AppStorage("leftPanelWidth") private var leftPanelWidth: Double = 220
    @AppStorage("rightPanelWidth") private var rightPanelWidth: Double = 280

    var body: some View {
        ZStack {
            // Full-screen map (always behind everything)
            MapContainerView()
                .environmentObject(store.connectionStore)
                .environmentObject(store.tracerouteStore)

            // Left panel + resizer + trigger
            HStack(spacing: 0) {
                if leftPanelVisible {
                    ProcessListView(onCollapse: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { leftPanelVisible = false }
                    })
                    .environmentObject(store.connectionStore)
                    .frame(width: leftPanelWidth)
                    .background(
                        Color(NSColor.windowBackgroundColor)
                            .opacity(0.92)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    PanelResizer(width: $leftPanelWidth, range: 180...440)
                }

                // Left trigger button
                if !leftPanelVisible {
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { leftPanelVisible = true } }) {
                        Color.white.opacity(0.15)
                            .frame(width: 12)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                }

                Spacer()
            }

            // Right panel + resizer + trigger
            HStack(spacing: 0) {
                Spacer()

                // Right trigger button
                if !rightPanelVisible {
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { rightPanelVisible = true } }) {
                        Color.white.opacity(0.15)
                            .frame(width: 12)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                }

                if rightPanelVisible {
                    PanelResizer(width: $rightPanelWidth, range: 240...560, inverted: true)

                    DetailPanelView(onCollapse: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { rightPanelVisible = false }
                    })
                    .environmentObject(store.connectionStore)
                    .environmentObject(store.tracerouteStore)
                    .frame(width: rightPanelWidth)
                    .background(
                        Color(NSColor.windowBackgroundColor)
                            .opacity(0.92)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }

            // Top toolbar overlay
            VStack {
                HStack {
                    Spacer()

                    Button(action: { store.setPaused(!store.isPaused) }) {
                        Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 20)
                    }
                    .buttonStyle(.plain)
                    .background(store.isPaused ? Color.orange.opacity(0.85) : Color(NSColor.controlBackgroundColor).opacity(0.9))
                    .cornerRadius(4)
                    .help(store.isPaused
                          ? String(localized: "Resume Monitoring", bundle: .module)
                          : String(localized: "Pause Monitoring", bundle: .module))

                    if store.isPaused {
                        Text(String(localized: "Monitoring Paused", bundle: .module))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Picker("Data Source", selection: $selectedSource) {
                        ForEach(store.availableDataSources, id: \.self) { source in
                            Text(source).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .frame(width: 240)
                    .onChange(of: selectedSource) { newValue in
                        store.switchDataSource(to: newValue)
                    }
                    .onAppear {
                        selectedSource = store.currentDataSource
                    }
                    .onChange(of: store.dataSourceWarning) { _ in
                        selectedSource = store.currentDataSource
                    }
                    Spacer()
                }
                .padding(.top, 8)

                if let warning = store.dataSourceWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.system(size: 11))
                        Button(action: { store.dismissDataSourceWarning() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                    .cornerRadius(6)
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .sheet(isPresented: $store.isFirstRun) {
            SetupView()
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleDetailPanel"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                rightPanelVisible.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleLeftPanel"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                leftPanelVisible.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("FocusSearch"))) { _ in
            leftPanelVisible = true
        }

        // Keyboard shortcuts (zero-size buttons so SwiftUI registers the key commands)
        shortcutButton(key: "f", modifiers: .command) {
            NotificationCenter.default.post(name: .init("FocusSearch"), object: nil)
        }
        shortcutButton(key: "e", modifiers: .command) {
            NotificationCenter.default.post(name: .init("ExportConnections"), object: nil)
        }
        shortcutButton(key: ".", modifiers: .command) {
            store.setPaused(!store.isPaused)
        }
        shortcutButton(key: "l", modifiers: [.command, .shift]) {
            NotificationCenter.default.post(name: .init("ToggleLeftPanel"), object: nil)
        }
        shortcutButton(key: "d", modifiers: [.command, .shift]) {
            NotificationCenter.default.post(name: .init("ToggleDetailPanel"), object: nil)
        }
    }

    private func shortcutButton(key: String, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button(action: action) { EmptyView() }
            .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: modifiers)
            .frame(width: 0, height: 0)
            .opacity(0)
    }
}

/// A narrow invisible drag strip on a panel's inner edge that resizes it.
struct PanelResizer: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    /// True when the panel is anchored to the window's trailing edge, so
    /// dragging towards the leading edge grows it.
    var inverted: Bool = false

    @State private var startWidth: Double?
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.accentColor.opacity(0.5) : Color.clear)
            .frame(width: 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if startWidth == nil { startWidth = width }
                        let delta = (value.location.x - value.startLocation.x) * (inverted ? -1 : 1)
                        width = min(max((startWidth ?? width) + delta, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        startWidth = nil
                    }
            )
    }
}
