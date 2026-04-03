//
//  SearchFieldBridge.swift
//  CarryOver
//

import SwiftUI
import AppKit

struct SearchFieldBridge: NSViewRepresentable {
    @Binding var text: String
    @Binding var focusToken: Int
    var placeholder: String
    var onEsc: () -> Void
    var onMoveToList: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.delegate = context.coordinator
        context.coordinator.field = field
        context.coordinator.onEsc = onEsc
        context.coordinator.onMoveToList = onMoveToList
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.onEsc = onEsc
        context.coordinator.onMoveToList = onMoveToList
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        weak var field: NSTextField?
        var lastFocusToken: Int = 0
        var onEsc: (() -> Void)?
        var onMoveToList: (() -> Void)?

        init(text: Binding<String>) { _text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEsc?()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) ||
               commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onMoveToList?()
                return true
            }
            return false
        }
    }
}
