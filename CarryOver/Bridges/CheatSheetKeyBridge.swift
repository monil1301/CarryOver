//
//  CheatSheetKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct CheatSheetKeyBridge: NSViewRepresentable {
    var isOpen: Bool
    var onToggle: () -> Void
    var onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        context.coordinator.isOpen = isOpen
        context.coordinator.onToggle = onToggle
        context.coordinator.onClose = onClose
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isOpen = isOpen
        context.coordinator.onToggle = onToggle
        context.coordinator.onClose = onClose
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isOpen: Bool = false
        var onToggle: (() -> Void)?
        var onClose: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])

                // Esc closes cheat sheet when open
                if self.isOpen && event.keyCode == KeyCode.escape {
                    self.onClose?()
                    return nil
                }

                // ⌘/
                if flags == .command && event.keyCode == KeyCode.slash {
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
