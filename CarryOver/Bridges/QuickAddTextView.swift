//
//  QuickAddTextView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit

struct QuickAddTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var focusToken: Int
    var placeholder: String
    var onCommit: () -> Void
    var onMoveToList: () -> Void
    var onMoveToInput: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSView {
        // Container to mimic TextField styling
        let container = NSView()

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = CommitTextView()
        textView.delegate = context.coordinator
        textView.onCommit = onCommit
        textView.onMoveToList = onMoveToList
        textView.onMoveToInput = onMoveToInput

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.textColor = NSColor.labelColor
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 6, height: 7) // close to TextField padding
        textView.textContainer?.widthTracksTextView = true

        scroll.documentView = textView

        // Placeholder label (drawn on top when empty)
        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.isBordered = false
        placeholderLabel.isEditable = false
        placeholderLabel.font = textView.font
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        // Rounded border background (looks like TextField)
        let background = NSView()
        background.wantsLayer = true
        background.layer?.cornerRadius = 7
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.separatorColor.cgColor
        background.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.08).cgColor
        background.translatesAutoresizingMaskIntoConstraints = false

        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(background)
        container.addSubview(scroll)
        container.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            background.topAnchor.constraint(equalTo: container.topAnchor),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            placeholderLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            placeholderLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 7),
        ])

        // Store references for updates
        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel
        context.coordinator.updatePlaceholderVisibility(currentText: textView.string)
        context.coordinator.textView = textView
        context.coordinator.onMoveDown = onMoveToList
        context.coordinator.installKeyMonitorIfNeeded()

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text {
            tv.string = text
        }
        context.coordinator.updatePlaceholderVisibility(currentText: tv.string)
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                context.coordinator.textView?.window?.makeFirstResponder(context.coordinator.textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        weak var placeholderLabel: NSTextField?

        // ✅ focus support
        var lastFocusToken: Int = 0

        // ✅ down-arrow monitor support
        var onMoveDown: (() -> Void)?
        private var monitor: Any?

        init(text: Binding<String>) { _text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text = tv.string
            updatePlaceholderVisibility(currentText: tv.string)
        }

        func updatePlaceholderVisibility(currentText: String) {
            placeholderLabel?.isHidden = !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func installKeyMonitorIfNeeded() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                guard event.keyCode == KeyCode.downArrow else { return event }

                guard let tv = self.textView,
                      let window = tv.window,
                      window.isKeyWindow else { return event }

                // If the current first responder is our text view,
                // then the user is typing in our input.
                if let fr = window.firstResponder as AnyObject?,
                   fr === tv {
                    self.onMoveDown?()
                    return nil // consume
                }

                return event
            }
        }
        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

final class CommitTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onMoveToList: (() -> Void)?
    var onMoveToInput: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Return
        let isReturn = (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter)
        if isReturn {
            if event.modifierFlags.contains(.shift) {
                insertNewline(nil)
            } else {
                onCommit?()
            }
            return
        }

        // Tab / Shift+Tab
        if event.keyCode == KeyCode.tab {
            if event.modifierFlags.contains(.shift) {
                onMoveToInput?()   // Shift+Tab
            } else {
                onMoveToList?()    // Tab
            }
            return
        }

        // Optional: Cmd+Down / Cmd+Up
        if event.modifierFlags.contains(.command) && event.keyCode == KeyCode.downArrow {
            onMoveToList?()
            return
        }
        if event.modifierFlags.contains(.command) && event.keyCode == KeyCode.upArrow {
            onMoveToInput?()
            return
        }

        super.keyDown(with: event)
    }
}
