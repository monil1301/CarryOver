//
//  HotkeySettingsTab.swift
//  CarryOver
//
//  Created by Monil Shah on 29/03/26.
//

import SwiftUI
import AppKit
import HotKey

struct HotkeySettingsTab: View {
    let onChange: () -> Void

    @State private var isRecording = false
    @State private var displayText = HotkeyService.currentShortcutString()
    @State private var isDefault = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Global Shortcut
            SettingsSection("Global Shortcut") {
                HStack {
                    Text(displayText)
                        .font(.system(.title3, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .cornerRadius(6)

                    Spacer()

                    Button(isRecording ? "Recording…" : "Record Shortcut") {
                        isRecording.toggle()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Reset to Default") {
                        resetToDefault()
                    }
                    .disabled(isDefault || isRecording)
                }

                if isRecording {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Press a shortcut now…")
                            .font(.subheadline)

                        Text("Must include at least one modifier (⌘ ⌥ ⌃ ⇧). Esc to cancel, Delete to clear.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ShortcutRecorder(
                            onCancel: {
                                isRecording = false
                            },
                            onClear: {
                                resetToDefault()
                                isRecording = false
                            },
                            onRecorded: { keyName, mods in
                                HotkeyService.save(keyName: keyName, modifiers: mods)
                                displayText = HotkeyService.format(keyName: keyName, modifiers: mods)
                                isDefault = checkIsDefault()
                                isRecording = false
                                onChange()
                            }
                        )
                        .frame(height: 1)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }

                Text("This shortcut opens CarryOver from anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            HotkeyService.registerDefaults()
            displayText = HotkeyService.currentShortcutString()
            isDefault = checkIsDefault()
        }
    }

    private static let defaultFormat = HotkeyService.format(keyName: "space", modifiers: [.control, .option])

    private func checkIsDefault() -> Bool {
        displayText == Self.defaultFormat
    }

    private func resetToDefault() {
        HotkeyService.save(keyName: "space", modifiers: [.control, .option])
        displayText = HotkeyService.currentShortcutString()
        isDefault = true
        onChange()
    }
}
