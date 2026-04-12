//
//  LaterListKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct LaterListKeyBridge: NSViewRepresentable {
    var isOpen: Bool
    var isEditing: Bool
    var hasSelection: Bool
    var onReturn: () -> Bool
    var onMoveToToday: () -> Bool
    var onDelete: () -> Void
    var onFocusList: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        context.coordinator.isOpen = isOpen
        context.coordinator.isEditing = isEditing
        context.coordinator.hasSelection = hasSelection
        context.coordinator.onReturn = onReturn
        context.coordinator.onMoveToToday = onMoveToToday
        context.coordinator.onDelete = onDelete
        context.coordinator.onFocusList = onFocusList
        context.coordinator.install()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isOpen = isOpen
        context.coordinator.isEditing = isEditing
        context.coordinator.hasSelection = hasSelection
        context.coordinator.onReturn = onReturn
        context.coordinator.onMoveToToday = onMoveToToday
        context.coordinator.onDelete = onDelete
        context.coordinator.onFocusList = onFocusList
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isOpen: Bool = false
        var isEditing: Bool = false
        var hasSelection: Bool = false
        var onReturn: (() -> Bool)?
        var onMoveToToday: (() -> Bool)?
        var onDelete: (() -> Void)?
        var onFocusList: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.isOpen else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])

                // ↓ — focus list and select first row when nothing is selected
                if !self.isEditing && flags.isEmpty && event.keyCode == KeyCode.downArrow && !self.hasSelection {
                    self.onFocusList?()
                    return nil
                }

                // ⌘⏎ — move selected to Today
                if flags == .command && (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter) {
                    if self.onMoveToToday?() == true { return nil }
                    return event
                }

                // ⏎ — edit selected (only when not already editing)
                if !self.isEditing && flags.isEmpty && (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter) {
                    if self.onReturn?() == true { return nil }
                    return event
                }

                // ⌫ — delete selected (only when not editing)
                if !self.isEditing && flags.isEmpty && event.keyCode == KeyCode.delete {
                    self.onDelete?()
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
