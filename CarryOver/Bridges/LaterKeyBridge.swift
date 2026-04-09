//
//  LaterKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct LaterKeyBridge: NSViewRepresentable {
    var isOpen: Bool
    var isEditing: Bool
    var onToggle: () -> Void
    var onClose: () -> Void
    var onMoveToLater: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        context.coordinator.isOpen = isOpen
        context.coordinator.isEditing = isEditing
        context.coordinator.onToggle = onToggle
        context.coordinator.onClose = onClose
        context.coordinator.onMoveToLater = onMoveToLater
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isOpen = isOpen
        context.coordinator.isEditing = isEditing
        context.coordinator.onToggle = onToggle
        context.coordinator.onClose = onClose
        context.coordinator.onMoveToLater = onMoveToLater
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isOpen: Bool = false
        var isEditing: Bool = false
        var onToggle: (() -> Void)?
        var onClose: (() -> Void)?
        var onMoveToLater: (() -> Bool)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])

                // Esc closes Later when open and not editing
                if self.isOpen && !self.isEditing && event.keyCode == KeyCode.escape {
                    self.onClose?()
                    return nil
                }

                // ⌘⇧L – move selected task to Later
                if flags == [.command, .shift] && event.keyCode == KeyCode.l {
                    if self.onMoveToLater?() == true { return nil }
                }

                // ⌘L
                if flags == .command && event.keyCode == KeyCode.l {
                    self.onToggle?()
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
