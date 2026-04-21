import SwiftUI
import AppKit
import Combine

@main
struct NetScopeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About NetScope") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// MARK: - MenuBar Controller

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let statusItem: NSStatusItem
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupMenuBar()
        setupBindings()
    }

    private func setupMenuBar() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NetScope")
        button.imagePosition = .imageLeft
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupBindings() {
        AppStore.shared.connectionStore.$connections
            .receive(on: RunLoop.main)
            .sink { [weak self] connections in
                self?.updateStatusText(count: connections.count)
            }
            .store(in: &cancellables)
    }

    private func updateStatusText(count: Int) {
        guard let button = statusItem.button else { return }
        button.title = count > 0 ? "\(count)" : ""
        button.font = .systemFont(ofSize: 11, weight: .medium)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            toggleWindow()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open NetScope", action: #selector(toggleWindow), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit NetScope", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func showWindow() {
        if let window = window {
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            createWindow()
        }
    }

    @objc private func toggleWindow() {
        if let window = window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            createWindow()
        }
    }

    private func createWindow() {
        let contentView = MainWindowView()
            .frame(minWidth: 900, minHeight: 560)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window?.title = "NetScope"
        window?.contentView = NSHostingView(rootView: contentView)
        window?.minSize = NSSize(width: 900, height: 560)
        window?.isReleasedWhenClosed = false
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Add titlebar accessory button for toggling detail panel
        addDetailPanelToggleButton()
    }

    private func addDetailPanelToggleButton() {
        guard let window = window else { return }

        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 22))
        button.bezelStyle = .texturedRounded
        button.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Detail Panel")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggleDetailPanel)

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 22))
        accessoryView.addSubview(button)

        let controller = NSTitlebarAccessoryViewController()
        controller.view = accessoryView
        controller.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(controller)
    }

    @objc private func toggleDetailPanel() {
        NotificationCenter.default.post(name: Notification.Name("ToggleDetailPanel"), object: nil)
    }

    @objc private func showPreferences() {
        // TODO: Show preferences window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
