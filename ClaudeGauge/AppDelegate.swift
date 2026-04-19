import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    var usageStore = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingWidget()
        setupMenuBarItem()
    }

    func setupFloatingWidget() {
        let contentView = FloatingWidgetView()
            .environmentObject(usageStore)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = NSHostingView(rootView: contentView)

        // Position bottom-right corner
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 140
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
