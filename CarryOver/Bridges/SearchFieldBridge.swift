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

    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.translatesAutoresizingMaskIntoConstraints = false

        let background = SearchBackgroundView()
        background.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(background)
        container.addSubview(field)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0.5),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -0.5),
            background.topAnchor.constraint(equalTo: container.topAnchor, constant: 0.5),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -0.5),

            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            field.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        context.coordinator.field = field
        context.coordinator.onEsc = onEsc
        context.coordinator.onMoveToList = onMoveToList

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let field = context.coordinator.field else { return }
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

private final class SearchBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            self.layer?.borderColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.15).cgColor
            self.layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.06).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        }
    }
}
