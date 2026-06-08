import AppKit
import SwiftUI
import ToggleKit

// Menu bar agent + optional dashboard window.
// - Menu bar: a bolt status item that opens the SwiftUI panel (option A).
//   The icon is filled when any toggle is active, outline when all are off.
// - Dashboard: a real window openable from Dock / Spotlight / ⌘Tab / `togglebar dashboard`.
//   Option A activation policy: the Dock icon appears only while the window is open.

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()

        popover.behavior = .transient
        popover.animates = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        refreshIcon()
    }

    // MARK: - Menu bar icon + popover

    /// Reflects "any toggle active?" in the menu bar glyph.
    func refreshIcon() {
        let anyOn = ToggleEngine.loadConfig().toggles.contains { ToggleEngine.isOn($0) }
        let symbol = anyOn ? "bolt.fill" : "bolt"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ToggleBar")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        // Rebuild the panel each open so it shows live state.
        popover.contentViewController = NSHostingController(
            rootView: PanelView(
                onChange: { [weak self] in self?.refreshIcon() },
                onQuit: { NSApp.terminate(nil) },
                onDashboard: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.showDashboard()
                }
            )
        )
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - Dashboard window

    func showDashboard() {
        if dashboardWindow == nil {
            let hosting = NSHostingController(
                rootView: DashboardView(onChange: { [weak self] in self?.refreshIcon() })
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "ToggleBar"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 380, height: 460))
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            dashboardWindow = window
        }
        // Option A: show the Dock icon only while the window is open.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a quiet menu bar agent; drop the Dock icon.
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Open from Dock / Spotlight / ⌘Tab / URL scheme

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let wantsDashboard = urls.contains { $0.absoluteString.contains("dashboard") }
        if wantsDashboard { showDashboard() }
    }

    // MARK: - Minimal main menu (so ⌘W / ⌘Q work while the window is up)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide ToggleBar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ToggleBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
