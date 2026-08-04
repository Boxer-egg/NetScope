import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject private var store = AppStore.shared
    @State private var leftPanelVisible = true
    @State private var rightPanelVisible = true
    @State private var selectedSource: String = ""

    var body: some View {
        ZStack {
            // Full-screen map (always behind everything)
            MapContainerView()
                .environmentObject(store.connectionStore)
                .environmentObject(store.tracerouteStore)

            // Left panel + trigger
            HStack(spacing: 0) {
                if leftPanelVisible {
                    ProcessListView()
                        .environmentObject(store.connectionStore)
                        .frame(width: 220)
                        .background(
                            Color(NSColor.windowBackgroundColor)
                                .opacity(0.92)
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
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

            // Right panel + trigger
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
                    DetailPanelView()
                        .environmentObject(store.connectionStore)
                        .environmentObject(store.tracerouteStore)
                        .frame(width: 280)
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
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                    .cornerRadius(4)
                    .help(store.isPaused
                          ? String(localized: "Resume Monitoring", bundle: .module)
                          : String(localized: "Pause Monitoring", bundle: .module))

                    Picker("Data Source", selection: $selectedSource) {
                        ForEach(store.availableDataSources, id: \.self) { source in
                            Text(source).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
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
    }
}
