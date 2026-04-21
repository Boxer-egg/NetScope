import SwiftUI

struct MainWindowView: View {
    @ObservedObject private var store = AppStore.shared
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Column 1: Process List
            ProcessListView()
                .frame(minWidth: 220, maxWidth: 350)
                .environmentObject(store.connectionStore)
                .background(Color(NSColor.windowBackgroundColor))
        } content: {
            // Column 2: Map
            MapContainerView()
                .frame(minWidth: 400)
                .environmentObject(store.connectionStore)
                .environmentObject(store.tracerouteStore)
                .background(Color.black) // Dark background for map area
        } detail: {
            // Column 3: Details (Resizable)
            DetailPanelView()
                .frame(minWidth: 280, maxWidth: 450)
                .environmentObject(store.connectionStore)
                .environmentObject(store.tracerouteStore)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 1000, minHeight: 650)
        .sheet(isPresented: $store.isFirstRun) {
            SetupView()
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleDetailPanel"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                if columnVisibility == .all {
                    columnVisibility = .doubleColumn
                } else {
                    columnVisibility = .all
                }
            }
        }
    }
}
