//
//  SearchKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct SearchKeyBridge: NSViewRepresentable {
    var isEditing: Bool
    var isSearchActive: Bool
    var onActivate: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.isEditing = isEditing
        context.coordinator.isSearchActive = isSearchActive
        context.coordinator.onActivate = onActivate
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isEditing = isEditing
        context.coordinator.isSearchActive = isSearchActive
        context.coordinator.onActivate = onActivate
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isEditing: Bool = false
        var isSearchActive: Bool = false
        var onActivate: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard !self.isSearchActive else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                // Cmd+F
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])
                if flags == .command && event.keyCode == KeyCode.f {
                    if !self.isEditing {
                        self.onActivate?()
                        return nil
                    }
                    return event
                }

                // "/" key — only when not typing in any text input
                if flags.isEmpty, event.charactersIgnoringModifiers == "/" {
                    guard let fr = window.firstResponder else { return event }
                    let isTextInput = fr is NSTextView || fr is NSTextField
                    if !isTextInput && !self.isEditing {
                        self.onActivate?()
                        return nil
                    }
                }

                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
