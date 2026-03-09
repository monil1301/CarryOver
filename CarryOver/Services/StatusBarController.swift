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
    }

    func hidePopover(restoreFocus: Bool = true) {
        if !restoreFocus { skipFocusRestore = true }
        popover.performClose(nil)
    }

    func toggleFromHotKey() {
        if popover.isShown { hidePopover() } else { showPopover() }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        if skipFocusRestore {
            skipFocusRestore = false
        } else if let app = previousApp {
            app.activate()
        }
        previousApp = nil
    }
}
