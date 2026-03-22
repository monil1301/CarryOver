//
//  ListReorderKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct ListReorderKeyBridge: NSViewRepresentable {
    var onMoveUp: () -> Bool
    var onMoveDown: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var onMoveUp: (() -> Bool)?
        var onMoveDown: (() -> Bool)?

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])
                guard flags == .option else { return event }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))

                guard isListFocused else { return event }

                if event.keyCode == KeyCode.upArrow {
                    if self.onMoveUp?() == true { return nil }
                }

                if event.keyCode == KeyCode.downArrow {
                    if self.onMoveDown?() == true { return nil }
                }

                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
