import AppKit
import SwiftUI

private let statusBarSymbolNames = [
    "waveform.path.ecg",
    "gauge.medium",
    "chart.bar.fill"
]

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = UsageViewModel()
    private let authMirrorService = CodexAuthMirrorService()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let removedProfileKeys = try? CapturedProfileDedupeService.removeAllDuplicates(),
           !removedProfileKeys.isEmpty {
            try? AccountProfileStore.remove(profileKeys: removedProfileKeys)
        }
        authMirrorService.start()
        setupStatusItem()
        setupPopover()
        viewModel.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = authMirrorService.syncActiveAuth()
        authMirrorService.stop()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let img = statusBarSymbolNames.lazy.compactMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: "Codex Vitals")
        }.first
        img?.isTemplate = true
        button.image = img
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    // MARK: - Popover

    private func setupPopover() {
        let root = ContentView(viewModel: viewModel)
        let controller = NSHostingController(rootView: root)
        controller.preferredContentSize = Self.preferredContentSize
        if #available(macOS 13.0, *) {
            controller.sizingOptions = [.preferredContentSize]
        }

        popover = NSPopover()
        popover.contentSize = Self.preferredContentSize
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = controller
    }

    private func syncPopoverSizeToSelectedMode() {
        popover.contentViewController?.preferredContentSize = Self.preferredContentSize
        popover.contentSize = Self.preferredContentSize
    }

    private static var preferredContentSize: NSSize {
        NSSize(width: ContentView.preferredWidth, height: ContentView.preferredHeight())
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            syncPopoverSizeToSelectedMode()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.popover.performClose(nil)
                self?.removeEventMonitor()
            }
        }
    }

    private func removeEventMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // hide from Dock
    app.run()
}
