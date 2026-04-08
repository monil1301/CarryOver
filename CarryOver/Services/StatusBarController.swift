//
//  StatusBarController.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import AppKit
import SwiftUI

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let beforeShow: () -> Void

    private var previousApp: NSRunningApplication?
    private var skipFocusRestore = false
    private var globalClickMonitor: Any?

    init<Content: View>(rootView: Content, beforeShow: @escaping () -> Void) {
        self.beforeShow = beforeShow
        // 1) Popover first
        let p = NSPopover()
        p.behavior = .transient
        p.contentSize = NSSize(width: 380, height: 480)
        p.contentViewController = NSHostingController(rootView: rootView)
        self.popover = p

        // 2) Status item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        super.init()

        popover.delegate = self

        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "CarryOver")?
                .withSymbolConfiguration(config)

            button.image = image
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        beforeShow()
        guard let button = statusItem.button else { return }

        // Remember the app that was active BEFORE we activate CarryOver
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)

        // Dismiss on clicks outside the app (e.g. other menu bar icons)
        // .transient doesn't catch these, so we add a global monitor.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.hidePopover(restoreFocus: false)
        }
    }

    func hidePopover(restoreFocus: Bool = true) {
        guard popover.isShown else { return }
        if !restoreFocus { skipFocusRestore = true }
        popover.performClose(nil)
    }

    func toggleFromHotKey() {
        if popover.isShown { hidePopover() } else { showPopover() }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }

        if skipFocusRestore {
            skipFocusRestore = false
            previousApp = nil
            return
        }

        // Defer by one tick so SettingsLink has time to create the window
        let savedApp = previousApp
        previousApp = nil
        DispatchQueue.main.async {
            if NSApp.windows.contains(where: { $0.isVisible && $0.title == "CarryOver Settings" }) {
                NSApp.activate(ignoringOtherApps: true)
            } else {
                savedApp?.activate()
            }
        }
    }
}
