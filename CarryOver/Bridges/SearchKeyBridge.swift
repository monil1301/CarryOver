//
//  SearchKeyBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct SearchKeyBridge: NSViewRepresentable {
    var isEditing: Bool
    var isSearchActive: Bool
    var isOverlayOpen: Bool = false
    var onActivate: () -> Void
    var onClose: () -> Void
    var onFocusInput: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.install()
        context.coordinator.hostView = v
        context.coordinator.isEditing = isEditing
        context.coordinator.isSearchActive = isSearchActive
        context.coordinator.isOverlayOpen = isOverlayOpen
        context.coordinator.onActivate = onActivate
        context.coordinator.onClose = onClose
        context.coordinator.onFocusInput = onFocusInput
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.isEditing = isEditing
        context.coordinator.isSearchActive = isSearchActive
        context.coordinator.isOverlayOpen = isOverlayOpen
        context.coordinator.onActivate = onActivate
        context.coordinator.onClose = onClose
        context.coordinator.onFocusInput = onFocusInput
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var hostView: NSView?
        var isEditing: Bool = false
        var isSearchActive: Bool = false
        var isOverlayOpen: Bool = false
        var onActivate: (() -> Void)?
        var onClose: (() -> Void)?
        var onFocusInput: (() -> Void)?

        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard let window = self.hostView?.window, window.isKeyWindow else { return event }

                // Esc closes search when active (from any focus)
                if self.isSearchActive && event.keyCode == KeyCode.escape {
                    self.onClose?()
                    return nil
                }

                guard !self.isSearchActive else { return event }

                // Cmd+F — pass through when an overlay is open so the overlay's bridge handles it
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting([.numericPad, .function])
                if flags == .command && event.keyCode == KeyCode.f {
                    if self.isOverlayOpen { return event }
                    if !self.isEditing {
                        self.onActivate?()
                        return nil
                    }
                    return event
                }

                // "/" key — focus add-task input (only when not typing in any text input)
                if flags.isEmpty, event.charactersIgnoringModifiers == "/" {
                    guard let onFocusInput = self.onFocusInput else { return event }
                    guard let fr = window.firstResponder else { return event }
                    let isTextInput = fr is NSTextView || fr is NSTextField
                    if !isTextInput && !self.isEditing {
                        onFocusInput()
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
