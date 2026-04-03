//
//  DatePickerEscBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct DatePickerEscBridge: NSViewRepresentable {
    var isOpen: Bool
    var onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        context.coordinator.isOpen = isOpen
        context.coordinator.onClose = onClose
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isOpen = isOpen
        context.coordinator.onClose = onClose
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isOpen: Bool = false
        var onClose: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.isOpen else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                if event.keyCode == KeyCode.escape {
                    self.onClose?()
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
