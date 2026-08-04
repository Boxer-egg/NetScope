import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var store = AppStore.shared

    var body: some View {
        Form {
            Section(header: Text(String(localized: "Monitoring", bundle: .module))) {
                Picker(String(localized: "Refresh Interval", bundle: .module), selection: $settings.refreshInterval) {
                    Text(String(localized: "1 second", bundle: .module)).tag(1.0)
                    Text(String(localized: "2 seconds", bundle: .module)).tag(2.0)
                    Text(String(localized: "5 seconds", bundle: .module)).tag(5.0)
                }
                .onChange(of: settings.refreshInterval) { _ in
                    store.applyRefreshInterval()
                }

                Toggle(String(localized: "Pause Monitoring", bundle: .module), isOn: Binding(
                    get: { store.isPaused },
                    set: { store.setPaused($0) }
                ))
            }

            Section(header: Text(String(localized: "Privacy", bundle: .module))) {
                Toggle(String(localized: "Allow Online GeoIP Lookup", bundle: .module), isOn: $settings.allowOnlineGeoIP)
                Text(String(localized: "When enabled, public IP addresses are sent to ip-api.com to resolve locations if the local database is unavailable.", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section(header: Text(String(localized: "Setup", bundle: .module))) {
                Button(String(localized: "Show GeoIP Setup Again…", bundle: .module)) {
                    store.isFirstRun = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
