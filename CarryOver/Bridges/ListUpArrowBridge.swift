//
//  ListUpArrowBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit

/// Listens for Up Arrow while the SwiftUI List is focused.
/// Consumes the key event ONLY if `onUpArrow()` returns true.
struct ListUpArrowBridge: NSViewRepresentable {
    var shouldHandle: () -> Bool
    var onUpArrow: () -> Bool   // ✅ returns whether we handled it

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.shouldHandle = shouldHandle
        context.coordinator.onUpArrow = onUpArrow
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.shouldHandle = shouldHandle
        context.coordinator.onUpArrow = onUpArrow
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var shouldHandle: (() -> Bool)?
        var onUpArrow: (() -> Bool)?

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.shouldHandle?() == true else { return event }

                guard event.keyCode == KeyCode.upArrow else { return event }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                // Only react if focus is currently in a List's table/outline view.
                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))

                guard isListFocused else { return event }

                // ✅ Only consume if handler says it handled it
                if self.onUpArrow?() == true {
                    return nil
                }

                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
