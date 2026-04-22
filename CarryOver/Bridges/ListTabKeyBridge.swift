//
//  ListTabKeyBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 22/04/26.
//

import SwiftUI
import AppKit

/// Listens for Tab / Shift+Tab while the SwiftUI List is focused. Consumes the key event
/// only if the corresponding callback returns true — Tab otherwise retains its default role
/// of cycling focus rings between controls.
struct ListTabKeyBridge: NSViewRepresentable {
    var isEditing: Bool
    var onTab: () -> Bool
    var onShiftTab: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.onTab = onTab
        context.coordinator.onShiftTab = onShiftTab
        context.coordinator.isEditing = isEditing
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onTab = onTab
        context.coordinator.onShiftTab = onShiftTab
        context.coordinator.isEditing = isEditing
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var onTab: (() -> Bool)?
        var onShiftTab: (() -> Bool)?
        var isEditing: Bool = false

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                guard event.keyCode == KeyCode.tab else { return event }
                guard !self.isEditing else { return event }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))

                guard isListFocused else { return event }

                let isShift = event.modifierFlags.contains(.shift)
                let handled = isShift ? (self.onShiftTab?() == true) : (self.onTab?() == true)
                return handled ? nil : event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
