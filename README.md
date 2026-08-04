# NetScope

macOS network connection monitor with interactive world map visualization. See which apps are talking to which servers, where they are, and trace the network path.

## Features

- **Real-time monitoring**: Polls `nettop` every second for live TCP/UDP connections
- **Process-level detail**: Friendly process names matching Activity Monitor / Dock
- **World map visualization**: Quadratic Bezier curves drawn on MapKit showing connection paths
- **Immersive layout**: Full-screen map with sliding left/right panels (process list + connection details)
- **Built-in Traceroute**: Per-hop latency and geographic visualization
- **GeoIP lookup**: Local MaxMind GeoLite2 database with online fallback (ip-api.com)
- **Auto-setup**: Drag-and-drop MMDB file or enter MaxMind license key to auto-download

## Requirements

- macOS 13 Ventura+
- Xcode 15+
- Swift 5.9+

## Building

```bash
swift build
```

Or open `Package.swift` in Xcode.

To create a release binary:

```bash
swift build -c release
# Binary at .build/release/NetScope
```

## GeoLite2 Database Setup

On first launch, a setup sheet appears with two options:

1. **Drag & Drop**: Download `GeoLite2-City.mmdb` from [MaxMind](https://www.maxmind.com/en/geolite2/signup) and drop it into the setup view
2. **License Key**: Enter your MaxMind Account ID + License Key to auto-download and extract the database

The database is saved to `~/Library/Application Support/NetScope/GeoLite2-City.mmdb`.

## Architecture

```
Sources/NetScope/
├── App/
│   └── NetScopeApp.swift          # App lifecycle, MenuBar, window management
├── Models/
│   ├── Connection.swift           # Network connection model
│   ├── GeoInfo.swift              # GeoIP location data
│   └── TracerouteHop.swift        # Traceroute hop model
├── Data/
│   ├── ConnectionSource.swift     # Source protocol (update/failure callbacks, poll interval)
│   ├── ConnectionProvider.swift   # Source switching, restart, failure routing
│   ├── NetworkStatisticsSource.swift  # Private NetworkStatistics.framework source (default)
│   ├── NettopConnectionSource.swift   # nettop parser & background polling (fallback)
│   ├── GeoDatabase.swift          # MaxMind DB reader + online fallback + negative cache
│   ├── TracerouteRunner.swift     # traceroute/traceroute6 execution
│   └── IPUtils.swift              # Private-IP detection, shell helper
├── Stores/
│   ├── AppStore.swift             # Global state, pause/resume, source fallback
│   ├── ConnectionStore.swift      # Connection aggregation, session totals, geo lookup
│   ├── TracerouteStore.swift      # Traceroute state management
│   └── SettingsStore.swift        # Persisted preferences (interval, privacy, setup skip)
└── Views/
    ├── MainWindowView.swift       # ZStack overlay layout with sliding panels
    ├── MapContainerView.swift     # MKMapView representable with Bezier curves
    ├── ProcessListView.swift      # Left panel: process list with traffic stats
    ├── DetailPanelView.swift      # Right panel: summary, states, hosts, connections, export
    ├── MenuBarPopoverView.swift   # Menu bar quick view (top talkers, pause, quit)
    ├── SettingsView.swift         # Preferences window
    ├── SetupView.swift            # First-run onboarding (drag-drop / license key)
    └── TracerouteView.swift       # Traceroute result display
```

## Testing

```bash
swift test
```

## License

MIT License. GeoLite2 database is subject to MaxMind's EULA and must be downloaded separately.
