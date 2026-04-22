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
                    self.errorMessage = String(localized: "Please drop the correct GeoLite2-City.mmdb file.", bundle: .module)
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
                self.errorMessage = String(format: String(localized: "Failed to copy file: %@", bundle: .module), error.localizedDescription)
            }
        }
    }

    private func downloadDatabase() {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        isDownloading = true
        errorMessage = nil

        var components = URLComponents(string: "https://download.maxmind.com/app/geoip_download")!
        components.queryItems = [
            URLQueryItem(name: "edition_id", value: "GeoLite2-City"),
            URLQueryItem(name: "license_key", value: trimmedKey),
            URLQueryItem(name: "suffix", value: "tar.gz")
        ]
        guard let url = components.url else {
            errorMessage = String(localized: "Invalid download URL", bundle: .module)
            isDownloading = false
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetScope", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid server response", bundle: .module)])
                }

                switch httpResponse.statusCode {
                case 200:
                    break
                case 401:
                    throw NSError(domain: "NetScope", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid license key. Please verify your MaxMind account and key.", bundle: .module)])
                default:
                    throw NSError(domain: "NetScope", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: String(format: String(localized: "Download failed (HTTP %d). Please try again.", bundle: .module), httpResponse.statusCode)])
                }

                // Validate that data is a tar.gz (magic number: 1f 8b)
                guard data.count > 2, data[0] == 0x1f, data[1] == 0x8b else {
                    throw NSError(domain: "NetScope", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Downloaded file is not a valid archive. Check your license key.", bundle: .module)])
                }

                let tempDir = FileManager.default.temporaryDirectory
                let tarPath = tempDir.appendingPathComponent("GeoLite2-City.tar.gz")
                try data.write(to: tarPath)

                let extractDir = tempDir.appendingPathComponent("geolite_extract_\(Int(Date().timeIntervalSince1970))")
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let tarTask = Process()
                tarTask.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                tarTask.arguments = ["-xzf", tarPath.path, "-C", extractDir.path]
                try tarTask.run()
                tarTask.waitUntilExit()

                guard tarTask.terminationStatus == 0 else {
                    throw NSError(domain: "NetScope", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Failed to extract archive", bundle: .module)])
                }

                var mmdbURL: URL?
                let enumerator = FileManager.default.enumerator(at: extractDir, includingPropertiesForKeys: nil)
                while let fileURL = enumerator?.nextObject() as? URL {
                    if fileURL.lastPathComponent == "GeoLite2-City.mmdb" {
                        mmdbURL = fileURL
                        break
                    }
                }

                guard let source = mmdbURL else {
                    throw NSError(domain: "NetScope", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Database file not found in downloaded archive", bundle: .module)])
                }

                let appSupport = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/NetScope", isDirectory: true)
                if !FileManager.default.fileExists(atPath: appSupport.path) {
                    try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
                }

                let destination = appSupport.appendingPathComponent("GeoLite2-City.mmdb")
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: source, to: destination)

                try? FileManager.default.removeItem(at: tarPath)
                try? FileManager.default.removeItem(at: extractDir)

                // Load database before dismissing, and verify it loaded
                await GeoDatabase.shared.loadDatabase()
                let hasDB = await GeoDatabase.shared.hasLocalDatabase()
                guard hasDB else {
                    throw NSError(domain: "NetScope", code: 4,
                                  userInfo: [NSLocalizedDescriptionKey: String(localized: "Database saved but could not be loaded. Please restart the app.", bundle: .module)])
                }

                await MainActor.run {
                    store.isFirstRun = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                self.isDownloading = false
            }
        }
    }
}
