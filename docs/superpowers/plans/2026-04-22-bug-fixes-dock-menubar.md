# Bug Fixes: Dock, Menu Bar, and Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three macOS app lifecycle bugs: Dock click not reopening window, menu bar items grayed out, and Cmd+Tab not bringing window forward.

**Architecture:** Three small, independent fixes in `NetScopeApp.swift`. No new files or abstractions needed.

**Tech Stack:** Swift 5.9, macOS 13+, AppKit

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Sources/NetScope/App/NetScopeApp.swift` | Modify | `AppDelegate` + `MenuBarController` — all three fixes |

---

### Task 1: Fix Dock click not reopening window

**Files:**
- Modify: `Sources/NetScope/App/NetScopeApp.swift`

- [ ] **Step 1: Add `applicationShouldHandleReopen` to `AppDelegate`**

Add this method inside `AppDelegate` (after `applicationDidFinishLaunching`):

```swift
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    menuBarController?.showWindow()
    return true
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/App/NetScopeApp.swift
git commit -m "fix: reopen window on Dock click after close"
```

---

### Task 2: Fix menu bar items grayed out

**Files:**
- Modify: `Sources/NetScope/App/NetScopeApp.swift`

- [ ] **Step 1: Rewrite `showContextMenu` to set `target` on each item**

Replace the entire `showContextMenu(_:)` method in `MenuBarController`:

```swift
private func showContextMenu(_ sender: NSStatusBarButton) {
    let menu = NSMenu()

    let openItem = NSMenuItem(title: "Open NetScope", action: #selector(toggleWindow), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)

    menu.addItem(NSMenuItem.separator())

    let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
    prefsItem.target = self
    menu.addItem(prefsItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(title: "Quit NetScope", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/App/NetScopeApp.swift
git commit -m "fix: set target on menu bar context menu items"
```

---

### Task 3: Fix Cmd+Tab not bringing window forward

**Files:**
- Modify: `Sources/NetScope/App/NetScopeApp.swift`

- [ ] **Step 1: Add `applicationDidBecomeActive` to `AppDelegate`**

Add this method inside `AppDelegate`:

```swift
func applicationDidBecomeActive(_ notification: Notification) {
    menuBarController?.showWindow()
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/NetScope/App/NetScopeApp.swift
git commit -m "fix: show window when app becomes active via Cmd+Tab"
```

---

### Task 4: Final verification

- [ ] **Step 1: Full build and test**

Run: `swift build && swift test`
Expected: ALL PASS

- [ ] **Step 2: Final commit**

```bash
git commit --allow-empty -m "feat: complete bug fixes for Dock, menu bar, and activation"
```

---

## Self-Review

### Spec coverage

| Spec Requirement | Task |
|------------------|------|
| Dock click reopens window | Task 1 |
| Menu bar items clickable | Task 2 |
| Cmd+Tab brings window forward | Task 3 |

All covered.

### Placeholder scan

No TBD/TODO placeholders. All code is complete.

### Type consistency

All methods reference `AppDelegate` and `MenuBarController` which already exist in the file. No new types introduced.
