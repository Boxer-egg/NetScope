# Bug Fixes: Dock, Menu Bar, and Activation Design

## Background

NetScope has three reported bugs in its macOS app lifecycle and menu bar integration:

1. **Dock click does not reopen window** — After closing the main window, clicking the app icon in the Dock does nothing.
2. **Menu bar items are grayed out** — Right-clicking the menu bar icon shows a context menu, but the items (Open NetScope, Preferences, Quit) are disabled.
3. **Cmd+Tab activation fails** — Switching to NetScope via Cmd+Tab sometimes does not bring the window to the foreground.

## Root Cause Analysis

### Bug 1: Dock Click

`AppDelegate` does not implement `applicationShouldHandleReopen(_:hasVisibleWindows:)`. When the user closes the window and clicks the Dock icon, AppKit calls this delegate method. Without an implementation, the default behavior is a no-op.

### Bug 2: Grayed-Out Menu Items

`MenuBarController.showContextMenu(_:)` creates `NSMenuItem` instances with actions targeting selectors like `#selector(toggleWindow)`. However, it never sets the `target` property on the menu items. The default target is `nil` (First Responder), and `MenuBarController` is not in the responder chain, so the selectors cannot be resolved → items appear disabled.

### Bug 3: Cmd+Tab

`NSApp.setActivationPolicy(.regular)` is correctly set, so the app appears in the Cmd+Tab switcher. However, when the app becomes active (e.g., via Cmd+Tab), there is no handler to ensure the window is visible. The window may have been closed or ordered out, leaving the app active with no visible UI.

## Fixes

### Fix 1: Dock Click → `applicationShouldHandleReopen`

Add to `AppDelegate`:
```swift
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    menuBarController?.showWindow()
    return true
}
```

### Fix 2: Menu Items → Set `target`

In `MenuBarController.showContextMenu(_:)`, change from:
```swift
menu.addItem(withTitle: "Open NetScope", action: #selector(toggleWindow), keyEquivalent: "")
```

To:
```swift
let openItem = NSMenuItem(title: "Open NetScope", action: #selector(toggleWindow), keyEquivalent: "")
openItem.target = self
menu.addItem(openItem)
```

Apply the same pattern to "Preferences…" and "Quit NetScope" items.

### Fix 3: Cmd+Tab → `applicationDidBecomeActive`

Add to `AppDelegate`:
```swift
func applicationDidBecomeActive(_ notification: Notification) {
    menuBarController?.showWindow()
}
```

This ensures the window is shown whenever the app becomes active, whether via Cmd+Tab, Dock click, or any other activation path.

## Files Modified

- `Sources/NetScope/App/NetScopeApp.swift`

## Testing

- Manual test: Close window, click Dock icon → window reopens.
- Manual test: Right-click menu bar icon, verify all three items are clickable.
- Manual test: Close window, Cmd+Tab to NetScope → window reopens.
