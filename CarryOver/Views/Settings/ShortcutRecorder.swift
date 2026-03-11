//
//  ShortcutRecorder.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit

/// A small view that becomes first responder and captures the next key press.
/// - Esc cancels
/// - Backspace/Delete clears (optional)
struct ShortcutRecorder: NSViewRepresentable {
    var onCancel: () -> Void
    var onClear: () -> Void
    var onRecorded: (_ keyName: String, _ modifiers: NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.onCancel = onCancel
        v.onClear = onClear
        v.onRecorded = onRecorded
        DispatchQueue.main.async {
            v.window?.makeFirstResponder(v)
        }
        return v
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class RecorderNSView: NSView {
    var onCancel: (() -> Void)?
    var onClear: (() -> Void)?
    var onRecorded: ((_ keyName: String, _ modifiers: NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // ESC cancels
        if event.keyCode == KeyCode.escape {
            onCancel?()
            return
        }

        // Delete / Backspace clears
        if event.keyCode == KeyCode.delete || event.keyCode == KeyCode.forwardDelete {
            onClear?()
            return
        }

        // We strongly recommend at least one modifier for global hotkeys
        if mods.isEmpty {
            NSSound.beep()
            return
        }

        // Map the pressed key into our stored "keyName"
        guard let keyName = HotkeyService.keyName(fromKeyCode: event.keyCode, characters: event.charactersIgnoringModifiers) else {
            NSSound.beep()
            return
        }

        onRecorded?(keyName, mods)
    }
}
