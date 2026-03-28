//
//  SettingsView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit
import HotKey
import ServiceManagement
internal import Sparkle

struct SettingsView: View {
    let updater: SPUUpdater
    let onChange: () -> Void

    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isRecording = false
    @State private var displayText = HotkeyService.currentShortcutString()

    init(updater: SPUUpdater, onChange: @escaping () -> Void) {
        self.updater = updater
        self.onChange = onChange
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey")
                .font(.headline)

            HStack {
                Text("Current:")
                    .foregroundStyle(.secondary)
                Text(displayText)
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }

            if isRecording {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Press a shortcut now…")
                        .font(.subheadline)

                    Text("• Must include at least one modifier (⌘ ⌥ ⌃ ⇧)\n• Esc to cancel\n• Delete to clear")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Invisible-ish capture surface
                    ShortcutRecorder(
                        onCancel: {
                            isRecording = false
                        },
                        onClear: {
                            // Reset to default
                            HotkeyService.registerDefaults()
                            let (key, mods) = HotkeyService.load()
                            let keyName = HotkeyService.availableKeys.first(where: { $0.key == key })?.name ?? "space"
                            HotkeyService.save(keyName: keyName, modifiers: mods)
                            displayText = HotkeyService.format(keyName: keyName, modifiers: mods)
                            isRecording = false
                            onChange()
                        },
                        onRecorded: { keyName, mods in
                            HotkeyService.save(keyName: keyName, modifiers: mods)
                            displayText = HotkeyService.format(keyName: keyName, modifiers: mods)
                            isRecording = false
                            onChange()
                        }
                    )
                    .frame(height: 1) // capture focus without showing a big control
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }

            HStack {
                Button(isRecording ? "Recording…" : "Record Shortcut") {
                    isRecording.toggle()
                }
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Close") {
                    NSApp.keyWindow?.close()
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 420, height: isRecording ? 260 : 170)
        .onAppear {
            HotkeyService.registerDefaults()
            displayText = HotkeyService.currentShortcutString()
        }
        
        Divider()

        Toggle("Open at Login", isOn: $launchAtLogin)
            .padding(.horizontal, 16)
            .onChange(of: launchAtLogin) { newValue in
                if newValue {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }

        Divider()

        Toggle("Check for updates automatically", isOn: Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.automaticallyChecksForUpdates = $0 }
        ))
        .padding(.horizontal, 16)

        Button("Check now") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
        .padding(.horizontal, 16)

        Divider()

        Text("Navigation shortcuts")
            .font(.headline)

        VStack(alignment: .leading, spacing: 6) {
            Text("• Today: ⌘T")
            Text("• Previous day: ⌘[")
            Text("• Next day: ⌘]")
            Text("• Pick date: ⌘P")
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.secondary)
    }
}
