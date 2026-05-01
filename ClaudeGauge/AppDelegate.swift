import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    var usageStore = UsageStore()
    var versionChecker = VersionChecker()

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingWidget()
        setupMenuBarItem()
        usageStore.requestNotificationPermission()
        versionChecker.checkForUpdate()
    }

    func setupFloatingWidget() {
        let swiftUIView = FloatingWidgetView()
            .environmentObject(usageStore)
            .environmentObject(versionChecker)

        let hostingView = NSHostingView(rootView: swiftUIView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = hostingView

        // Position bottom-right corner
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 420
            let y = screen.visibleFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        self.floatingWindow = window
    }

    func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Claude Gauge")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Claude Gauge", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show Widget", action: #selector(showWidget), keyEquivalent: "w")
        menu.addItem(withTitle: "Hide Widget", action: #selector(hideWidget), keyEquivalent: "h")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    @objc func showWidget() {
        floatingWindow?.orderFrontRegardless()
    }

    @objc func hideWidget() {
        floatingWindow?.orderOut(nil)
    }
}
