# NetworkStatistics.framework Migration Design

## Background & Motivation

NetScope currently polls network connection data by shelling out to `/usr/bin/nettop` every second and parsing its CSV text output with regular expressions. This approach has four known weaknesses:

1. **Performance**: Forking a process every second is wasteful.
2. **Fragility**: nettop output format changes can break regex-based parsing.
3. **Extensibility**: Text parsing limits what data fields we can extract.
4. **Architecture**: Shelling out is a workaround, not a first-class data source.

`NetworkStatistics.framework` (a macOS private framework) exposes the same underlying data as a structured Objective-C API, eliminating text parsing entirely.

## Goals

1. Introduce a `ConnectionSource` abstraction so data acquisition is pluggable.
2. Retain the existing `nettop` backend as the default.
3. Add a `NetworkStatistics.framework` backend, selectable at runtime via UI.
4. Keep the `Connection` model unchanged — both backends produce the same output type.
5. Do not use local proxy or kernel extension — pure read-only monitoring.

## Non-Goals

- Traffic manipulation (blocking, throttling, etc.)
- App Store submission (app will be distributed via GitHub only)
- Replacing nettop immediately — it remains the safe default

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  MainWindowView │────▶│   ConnectionProvider │────▶│ ConnectionStore │
│  (source picker)│     │   (holds activeSource)│     │  (aggregation)  │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
         ┌────────────────────┐      ┌─────────────────────────┐
         │ NettopConnection   │      │ NetworkStatisticsSource │
         │ Source (default)   │      │ (experimental)          │
         └────────────────────┘      └─────────────────────────┘
```

## Detailed Design

### 1. ConnectionSource Protocol

```swift
protocol ConnectionSource: AnyObject {
    var onUpdate: (([Connection]) -> Void)? { get set }
    func start()
    func stop()
    var displayName: String { get }
}
```

### 2. NettopConnectionSource (Optimized)

- Replaces `ConnectionPoller`.
- Retains `nettop -L 1 -t external` shell execution.
- **Parser rewritten**: CSV output has a fixed column order. Use `components(separatedBy: ",")` with column indices instead of regex for all fields. Only use regex as a secondary validator, never as the primary extractor.
- Process name resolution logic moved into this class.

### 3. NetworkStatisticsSource

- Accesses `NetworkStatistics.framework` via Objective-C runtime (dynamic class lookup).
- Uses `NSClassFromString` + `performSelector` to call framework methods. No private header files.
- Maps framework objects to `Connection` structs.

Known framework classes (verified by Netiquette / netbottom):
- `NWSSnapshot` — root snapshot
- `NWSProtocolSnapshot` — per-protocol (TCP/UDP) container
- `NWSConnectionSnapshot` — individual connection

Key properties on connection snapshot (via `value(forKey:)`):
- `pid` → `Int`
- `processName` / `comm` → `String`
- `localAddress` / `localPort` → `String` / `Int`
- `remoteAddress` / `remotePort` → `String` / `Int`
- `bytesIn` / `bytesOut` → `Int64`
- `state` → `String` (e.g. "ESTABLISHED")
- `interfaceName` → `String`

Error handling: if any runtime class lookup fails, `start()` logs the error and emits an empty array. The UI shows "NetworkStatistics unavailable".

### 4. ConnectionProvider

```swift
class ConnectionProvider {
    private(set) var activeSource: ConnectionSource
    var onUpdate: (([Connection]) -> Void)?

    init(defaultSource: ConnectionSource)
    func switchTo(_ source: ConnectionSource)
}
```

`switchTo` stops the old source, clears `ConnectionStore`'s internal map (to avoid stale state from a different backend), and starts the new source.

### 5. UI Changes

Add a `Picker` in `MainWindowView` toolbar:
- Options: "nettop" (default) / "NetworkStatistics"
- On change: call `ConnectionProvider.switchTo(...)`

## Data Flow (Unchanged)

```
Source.onUpdate([Connection])
  → ConnectionStore.update(with:)
  → @Published connections
  → SwiftUI View re-render
```

`ConnectionStore` knows nothing about which source produced the data.

## Testing Strategy

1. **Protocol conformance**: Both sources conform to `ConnectionSource`.
2. **Nettop parser**: Existing `NettopParserTests` updated for column-index parsing.
3. **NetworkStatistics source**: Unit test verifies graceful degradation when framework classes are absent (e.g. on non-macOS or if Apple removes them).

## Risks & Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| NetworkStatistics API changes in future macOS | Low-Medium | nettop remains the default; fallback is one toggle away |
| Runtime class lookup fails (sandbox/entitlement) | Low | Not App Store — no sandbox restriction on private framework access |
| `Connection` model mismatch between sources | Low | Both backends tested against same `NettopParserTests` mock assertions |
| Performance regression in nettop path | None | nettop path is untouched except parser rewrite |

## Migration Path

1. Extract `ConnectionPoller` into `NettopConnectionSource` (refactor, no behavior change).
2. Rewrite parser to use column indices.
3. Add `ConnectionSource` protocol and `ConnectionProvider`.
4. Implement `NetworkStatisticsSource` with runtime bridging.
5. Add UI toggle.
6. Ship with nettop default, NetworkStatistics behind toggle.
