# NetScope UI Redesign Design Spec

**Date:** 2026-04-22
**Scope:** UI improvements, right panel features, setup flow completion

---

## 1. Overview

This spec covers a comprehensive UI/UX overhaul of NetScope's main interface, plus completion of the onboarding flow. The design is heavily inspired by Little Snitch's Network Monitor.

### Goals
- Make the map the primary visual focus (immersive design)
- Add sliding side panels that overlay the map
- Smooth connection curves on the map
- Friendly process names matching Activity Monitor/Dock
- Rich right panel with Summary, Statistics, and connection details
- Complete the License Key auto-download feature in setup

### Priority Order
1. UI Optimizations (sliding panels + curve smoothing + process names)
2. Right Panel Tabs (Summary + Statistics)
3. License Key Auto-Download

---

## 2. Layout Architecture

### 2.1 Current State
Three-column `NavigationSplitView` with fixed sidebar widths:
- Left: ProcessListView (220px)
- Center: MapContainerView (flexible)
- Right: DetailPanelView (280px)

### 2.2 Target State
Full-screen map with overlay side panels:
- **Map**: Full-screen background, always visible
- **Left Panel**: 220px wide, slides in from left edge with spring animation (0.3s)
- **Right Panel**: 280px wide, slides in from right edge with spring animation (0.3s)
- **Trigger Buttons**: 12px wide semi-transparent vertical bars at screen edges
- **Bottom Toolbar**: Traffic time range selector (centered, overlay)

### 2.3 Panel Behavior
- Both panels open by default on first launch
- State persisted in `UserDefaults`
- Trigger buttons visible when panel is collapsed, hidden when expanded
- Click trigger button → panel slides in (spring animation + opacity fade)
- Click outside panel or trigger button again → panel slides out
- Panels have `backdrop-filter: blur(20px)` with `rgba(30,30,40,0.95)` background

### 2.4 Implementation Strategy
Replace `NavigationSplitView` in `MainWindowView` with a `ZStack`:
```swift
ZStack {
    MapContainerView() // Full screen, z-index 0
    
    // Left panel overlay
    HStack {
        if leftPanelVisible { ProcessListView() }
        LeftTriggerButton()
        Spacer()
    }
    
    // Right panel overlay
    HStack {
        Spacer()
        RightTriggerButton()
        if rightPanelVisible { DetailPanelView() }
    }
}
```

---

## 3. Connection Curve Optimization

### 3.1 Problem
Current `MKGeodesicPolyline` produces large, exaggerated curves that visually "jump" across the map. The great-circle arc is too pronounced for short-to-medium distances.

### 3.2 Solution
Replace `MKGeodesicPolyline` with a custom `MKPolyline` using a quadratic Bezier curve control point:

```swift
// Calculate midpoint with a perpendicular offset
let controlPoint = midpoint.offset(perpendicular: distance * 0.15)
let polyline = MKPolyline(coordinates: [origin, controlPoint, destination], count: 3)
```

- Control point offset = 15% of the straight-line distance
- Direction: perpendicular to the straight line between origin and destination
- This creates a gentle, natural-looking arc without excessive curvature
- The `MKPolylineRenderer` will smooth the curve via the three-point interpolation

### 3.3 Renderer Update
Update `mapView(_:rendererFor:)` to use the stored per-connection color instead of always `.systemBlue`.

---

## 4. Process Name Beautification

### 4.1 Problem
`nettop` outputs raw process identifiers like `com.avg.daemon.453`, `Google Chrome H.74938`, `zerotier-one.284`. Users expect friendly names like "AVG AntiVirus", "Google Chrome", "ZeroTier".

### 4.2 Solution
In `ConnectionPoller.parseNettopRobust()`, after extracting the process name, attempt to map it to a friendly name via `NSWorkspace`:

```swift
func resolveFriendlyProcessName(_ rawName: String, pid: Int) -> String {
    let runningApps = NSWorkspace.shared.runningApplications
    
    // 1. Exact localizedName match
    if let app = runningApps.first(where: { $0.localizedName == rawName }) {
        return app.localizedName!
    }
    
    // 2. Match by PID (most reliable)
    if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
        return app.localizedName ?? rawName
    }
    
    // 3. Partial match (e.g. "Google Chrome H" → "Google Chrome")
    if let app = runningApps.first(where: { 
        let locName = $0.localizedName?.lowercased() ?? ""
        return rawName.lowercased().hasPrefix(locName) || locName.hasPrefix(rawName.lowercased())
    }) {
        return app.localizedName!
    }
    
    // 4. Fallback: keep original (strip PID suffix already done by regex)
    return rawName
}
```

### 4.3 Edge Cases
- System processes (`apsd`, `mDNSResponder`) that don't have running app entries → keep raw name
- Helper processes (`Google Chrome Helper`) → map to parent app name if possible
- Background daemons without UI (`com.avg.daemon`) → keep raw name (user chose option A)

---

## 5. Right Panel: Summary & Statistics

### 5.1 Current State
The right panel only shows a connection list with geo info and traceroute.

### 5.2 Target State
Expand the panel with a Summary/Statistics section above the existing connection list:

**Summary Section:**
- Process count, unique domain count
- Total traffic: received (blue) / sent (red) with styled cards

**Connections Section:**
- Connection state breakdown: Active, Established, Closing
- Count per state

**Top Processes Section:**
- Top 3-5 processes by total traffic (down + up)
- Show app icon, name, and traffic breakdown

**Top Domains Section:**
- Top 3-5 domains by total traffic
- Requires reverse DNS or using connection hostname data

**Connections Detail (existing, below divider):**
- Keep the current per-connection list with geo info

### 5.3 Data Sources
All data computed from `ConnectionStore.connections`:
- Process count: `Dictionary(grouping:).count`
- Domain count: reverse DNS lookup (or use hostname from nettop when available)
- Traffic totals: sum of `bytesIn` / `bytesOut`
- Top Processes: group by `processName`, sort by total bytes
- Top Domains: group by domain (from reverse DNS), sort by total bytes

### 5.4 UI Notes
- Each section is collapsible (optional V2 feature)
- Use existing `processColorsList` for consistent coloring
- Show app icons via existing `AppIconView`
- Section dividers between Summary → Connections → Top Processes → Top Domains → Connection Detail

---

## 6. License Key Auto-Download

### 6.1 Current State
`SetupView.downloadDatabase()` is a stub that shows "coming soon".

### 6.2 Target State
Full implementation of MaxMind GeoLite2 automatic download:

**Flow:**
1. User enters License Key in text field
2. Click "Download" button
3. Show progress indicator
4. POST to `https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key={key}&suffix=tar.gz`
5. Stream download to temp directory
6. Decompress tar.gz (use `Foundation` tar extraction or `/usr/bin/tar`)
7. Extract `GeoLite2-City.mmdb` from the archive
8. Move to `~/Library/Application Support/NetScope/GeoLite2-City.mmdb`
9. Call `GeoDatabase.shared.loadDatabase()`
10. Dismiss setup view

### 6.3 Error Handling
- Invalid key → show error message
- Network failure → retry option
- Corrupt download → cleanup and error

---

## 7. Files to Modify

| File | Changes |
|------|---------|
| `MainWindowView.swift` | Replace NavigationSplitView with ZStack + overlay panels |
| `MapContainerView.swift` | Replace MKGeodesicPolyline with custom curve, fix color renderer |
| `ProcessListView.swift` | Add trigger button support (or handle in MainWindowView) |
| `DetailPanelView.swift` | Add SummarySection, StatisticsSection views |
| `ConnectionStore.swift` | Add computed properties for summary statistics |
| `ConnectionPoller.swift` | Add process name resolution |
| `SetupView.swift` | Implement downloadDatabase() |
| `AppStore.swift` | Add panel visibility state |

---

## 8. Open Questions (None)

All clarifying questions have been resolved:
- Panel trigger: button-click (not hover/gesture)
- Right panel design: extend existing (not full tab replacement)
- Process names: match if possible, keep raw if not (option A)
