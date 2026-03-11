//
//  ListReturnKeyBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 11/03/26.
//

import SwiftUI
import AppKit

/// Listens for Return/Enter while the SwiftUI List is focused.
/// Consumes the key event ONLY if `onReturn()` returns true.
struct ListReturnKeyBridge: NSViewRepresentable {
    var onReturn: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.onReturn = onReturn
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onReturn = onReturn
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var onReturn: (() -> Bool)?

        private var monitor: Any?

        func install() {
            if monitor != nil { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                guard event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter else { return event }

                guard let window = self.hostView?.window, window.isKeyWindow else { return event }
                guard let fr = window.firstResponder else { return event }

                let isListFocused =
                    fr is NSTableView ||
                    fr is NSOutlineView ||
                    (fr is NSView && String(describing: type(of: fr)).contains("NSTable"))

                guard isListFocused else { return event }

                if self.onReturn?() == true {
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
