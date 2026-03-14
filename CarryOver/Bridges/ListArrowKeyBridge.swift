//
//  ListArrowKeyBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 14/03/26.
//

import SwiftUI
import AppKit

/// Listens for Left/Right arrow keys while the SwiftUI List is focused.
/// Used to expand/collapse the Completed section header.
struct ListArrowKeyBridge: NSViewRepresentable {
    var isHeaderSelected: () -> Bool
    var isCollapsed: () -> Bool
    var onExpand: () -> Void
    var onCollapse: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.isHeaderSelected = isHeaderSelected
        context.coordinator.isCollapsed = isCollapsed
        context.coordinator.onExpand = onExpand
        context.coordinator.onCollapse = onCollapse
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isHeaderSelected = isHeaderSelected
        context.coordinator.isCollapsed = isCollapsed
        context.coordinator.onExpand = onExpand
        context.coordinator.onCollapse = onCollapse
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isHeaderSelected: (() -> Bool)?
        var isCollapsed: (() -> Bool)?
        var onExpand: (() -> Void)?
        var onCollapse: (() -> Void)?

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                guard self.isHeaderSelected?() == true else { return event }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))

                guard isListFocused else { return event }

                // Right arrow → expand if collapsed
                if event.keyCode == KeyCode.rightArrow {
                    if self.isCollapsed?() == true {
                        self.onExpand?()
                        return nil
                    }
                }

                // Left arrow → collapse if expanded
                if event.keyCode == KeyCode.leftArrow {
                    if self.isCollapsed?() == false {
                        self.onCollapse?()
                        return nil
                    }
                }

                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
