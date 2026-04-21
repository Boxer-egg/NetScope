# NetScope

macOS Network Connection Monitor — A menu bar app that visualizes all process network connections on a world map.

## Features

- **Real-time monitoring**: Polls `lsof` every second to show all active TCP/UDP connections
- **Process-level granularity**: See which apps are connecting to which servers
- **World map visualization**: Connections drawn as arcs on MapKit with target IP locations
- **Built-in Traceroute**: Trace network paths with per-hop latency and geographic visualization
- **Offline-first GeoIP**: Uses local MaxMind GeoLite2 database (falls back to ip-api.com if unavailable)
- **Menu bar app**: Runs as agent (no Dock icon), shows connection count in status bar

## Requirements

- macOS 13 Ventura+
- Xcode 15+ (for building)
- Swift 6.0+

## Building

```bash
swift build
```

Or open `Package.swift` in Xcode and build from there.

To create a runnable `.app` bundle:

```bash
swift build -c release
# The binary will be at .build/release/NetScope
```

## GeoLite2 Database Setup

NetScope works out of the box using the online ip-api.com fallback, but for full offline privacy, download the MaxMind GeoLite2-City database:

### Option 1: Manual Download

1. Register a free account at [MaxMind](https://www.maxmind.com/en/geolite2/signup)
2. Log in and go to "Download Files"
3. Download **GeoLite2-City.mmdb** (MMDB format)
4. Place it at:
   ```
   ~/Library/Application Support/NetScope/GeoLite2-City.mmdb
   ```

### Option 2: Using geoipupdate (Recommended for keeping updated)

1. Install `geoipupdate`:
   ```bash
   brew install geoipupdate
   ```
2. Create `/usr/local/etc/GeoIP.conf` with your AccountID and LicenseKey from MaxMind
3. Run `geoipupdate` to download databases
4. Copy or symlink the database:
   ```bash
   mkdir -p ~/Library/Application\ Support/NetScope
   cp /usr/local/share/GeoIP/GeoLite2-City.mmdb ~/Library/Application\ Support/NetScope/
   ```

## Architecture

```
NetScope/
├── App/                    # AppDelegate, MenuBarController
├── Models/                 # Connection, GeoInfo, TracerouteHop
├── Data/                   # ConnectionPoller, TracerouteRunner, GeoDatabase
├── Stores/                 # ConnectionStore, TracerouteStore
└── Views/                  # SwiftUI views
```

## Testing

```bash
swift test
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Manual refresh connections |
| Cmd+F | Focus process search |
| Cmd+, | Open Preferences |
| Escape | Clear selection, show All |
| Cmd+T | Traceroute selected connection |
| Cmd+Shift+M | Toggle map type |

## Distribution

Phase 1 is distributed as a direct `.app` bundle (not Mac App Store due to `lsof` sandbox restrictions).

## License

MIT License. GeoLite2 database is subject to MaxMind's EULA and must be downloaded separately.
