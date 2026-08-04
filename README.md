# NetScope

A macOS network connection monitor with an interactive world map. It shows which apps are connecting to which servers, where those servers are, and traces the network path.

Built with SwiftUI + MapKit.

## Requirements

- macOS 13 Ventura+
- Xcode 15+ / Swift 5.9+

## Building

```bash
swift build
```

Release binary:

```bash
swift build -c release
# .build/release/NetScope
```

## GeoLite2 Database

The map needs the MaxMind GeoLite2-City database. On first launch, the setup sheet lets you either:

1. Drop a downloaded `GeoLite2-City.mmdb` file, or
2. Enter your MaxMind license key to download it automatically.

The database is saved to `~/Library/Application Support/NetScope/GeoLite2-City.mmdb`.

## Run Tests

```bash
swift test
```

## License

MIT License. The GeoLite2 database is subject to MaxMind's EULA and must be downloaded separately.

## 说明

NetScope 目前是一个**半成品**，部分功能仍在完善中，稳定性和边界情况处理有限。
