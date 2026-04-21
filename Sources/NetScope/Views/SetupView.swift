import SwiftUI
import AppKit

struct SetupView: View {
    @EnvironmentObject var store: AppStore
    @State private var isDragging = false
    @State private var licenseKey = ""
    @State private var isDownloading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Welcome to NetScope")
                    .font(.system(size: 24, weight: .bold))

                Text("To visualize connections on the map, we need the MaxMind GeoLite2 database.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .padding(.top, 40)

            VStack(spacing: 20) {
                // Option 1: Drag and Drop
                VStack(spacing: 10) {
                    Text("Option 1: Manual Install")
                        .font(.system(size: 14, weight: .semibold))

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDragging ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .background(isDragging ? Color.accentColor.opacity(0.05) : Color.clear)
                            .frame(height: 120)

                        VStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 24))
                            Text("Drop GeoLite2-City.mmdb here")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(isDragging ? .accentColor : .secondary)
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                        handleFileDrop(providers)
                    }

                    Button("Download from MaxMind...") {
                        if let url = URL(string: "https://www.maxmind.com/en/geolite2/signup") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                }
                .frame(width: 380)

                Divider().frame(width: 200)

                // Option 2: License Key
                VStack(spacing: 12) {
                    Text("Option 2: Use License Key")
                        .font(.system(size: 14, weight: .semibold))

                    HStack {
                        TextField("Enter MaxMind License Key", text: $licenseKey)
                            .textFieldStyle(.roundedBorder)

                        Button("Download") {
                            downloadDatabase()
                        }
                        .disabled(licenseKey.isEmpty || isDownloading)
                    }
                }
                .frame(width: 380)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            }

            Spacer()

            Button("I'll do this later") {
                store.isFirstRun = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            if url.lastPathComponent == "GeoLite2-City.mmdb" {
                installDatabase(from: url)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Please drop the correct GeoLite2-City.mmdb file."
                }
            }
        }
        return true
    }

    private func installDatabase(from sourceURL: URL) {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetScope", isDirectory: true)

        do {
            if !FileManager.default.fileExists(atPath: appSupport.path) {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            }

            let destinationURL = appSupport.appendingPathComponent("GeoLite2-City.mmdb")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            DispatchQueue.main.async {
                store.isFirstRun = false
                Task {
                    await GeoDatabase.shared.loadDatabase()
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to copy file: \(error.localizedDescription)"
            }
        }
    }

    private func downloadDatabase() {
        // Implementation for Stage 2 (Automatic download via Key)
        isDownloading = true
        errorMessage = "Automatic download is coming soon in Phase 2. Please use manual install for now."
        isDownloading = false
    }
}
