//
//  DatePickerEscBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct DatePickerKeyBridge: NSViewRepresentable {
    var isOpen: Bool
    var onClose: () -> Void
    var onArrow: (Int) -> Void
    var onShiftMonth: (Int) -> Void
    var onConfirm: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        context.coordinator.isOpen = isOpen
        context.coordinator.onClose = onClose
        context.coordinator.onArrow = onArrow
        context.coordinator.onShiftMonth = onShiftMonth
        context.coordinator.onConfirm = onConfirm
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isOpen = isOpen
        context.coordinator.onClose = onClose
        context.coordinator.onArrow = onArrow
        context.coordinator.onShiftMonth = onShiftMonth
        context.coordinator.onConfirm = onConfirm
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isOpen: Bool = false
        var onClose: (() -> Void)?
        var onArrow: ((Int) -> Void)?
        var onShiftMonth: ((Int) -> Void)?
        var onConfirm: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.isOpen else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])

                if flags.isEmpty && event.keyCode == KeyCode.escape {
                    self.onClose?()
                    return nil
                }

                // ⌘← / ⌘→ — shift month
                if flags == .command && event.keyCode == KeyCode.leftArrow {
                    self.onShiftMonth?(-1)
                    return nil
                }
                if flags == .command && event.keyCode == KeyCode.rightArrow {
                    self.onShiftMonth?(1)
                    return nil
                }

                // Plain arrow keys — navigate days
                if flags.isEmpty && event.keyCode == KeyCode.leftArrow {
                    self.onArrow?(-1)
                    return nil
                }
                if flags.isEmpty && event.keyCode == KeyCode.rightArrow {
                    self.onArrow?(1)
                    return nil
                }
                if flags.isEmpty && event.keyCode == KeyCode.upArrow {
                    self.onArrow?(-7)
                    return nil
                }
                if flags.isEmpty && event.keyCode == KeyCode.downArrow {
                    self.onArrow?(7)
                    return nil
                }

                if flags.isEmpty && (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter || event.keyCode == KeyCode.space) {
                    self.onConfirm?()
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
