//
//  ParentCollapseArrowBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 22/04/26.
//

import SwiftUI
import AppKit

/// Listens for Left / Right arrow keys while the List is focused and delegates to VM handlers
/// that collapse / expand a selected parent task. Consumes the event only when the handler
/// returned true; otherwise the key continues on to the existing header-collapse bridge and
/// SwiftUI List's default handling.
struct ParentCollapseArrowBridge: NSViewRepresentable {
    var onLeftArrow: () -> Bool
    var onRightArrow: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.onLeftArrow = onLeftArrow
        context.coordinator.onRightArrow = onRightArrow
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onLeftArrow = onLeftArrow
        context.coordinator.onRightArrow = onRightArrow
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var onLeftArrow: (() -> Bool)?
        var onRightArrow: (() -> Bool)?

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.keyCode == KeyCode.leftArrow || event.keyCode == KeyCode.rightArrow else {
                    return event
                }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))
                guard isListFocused else { return event }

                let handled: Bool = (event.keyCode == KeyCode.leftArrow)
                    ? (self.onLeftArrow?() ?? false)
                    : (self.onRightArrow?() ?? false)
                return handled ? nil : event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
