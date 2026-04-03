//
//  ShortcutsCheatSheetView.swift
//  CarryOver
//

import SwiftUI

struct ShortcutsCheatSheetView: View {
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                shortcutSection("NAVIGATION", shortcuts: [
                    ("Open app", ["⌃", "⌥", "Space"]),
                    ("Previous day", ["⌘", "["]),
                    ("Next day", ["⌘", "]"]),
                    ("Go to today", ["⌘", "T"]),
                    ("Date picker", ["⌘", "P"]),
                ])

                sectionDivider

                shortcutSection("TASKS", shortcuts: [
                    ("Add task", ["⏎", "Return"]),
                    ("Edit task", ["⏎", "Return"]),
                    ("Delete task", ["⌫", "Delete"]),
                    ("Toggle complete", ["Space"]),
                    ("Move up", ["⌘", "↑"]),
                    ("Move down", ["⌘", "↓"]),
                    ("Undo", ["⌘", "Z"]),
                ])

                sectionDivider

                shortcutSection("APP", shortcuts: [
                    ("Settings", ["⌘", ","]),
                    ("Keyboard shortcuts", ["⌘", "/"]),
                    ("Quit", ["⌘", "Q"]),
                ])
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onExitCommand { onDismiss() }
    }

    // MARK: - Section

    private func shortcutSection(_ title: String, shortcuts: [(String, [String])]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                shortcutRow(label: shortcut.0, keys: shortcut.1)
            }
        }
    }

    // MARK: - Row

    private func shortcutRow(label: String, keys: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    keyBadge(key)
                }
            }
        }
        .frame(height: 28)
    }

    // MARK: - Key Badge

    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 4)
    }
}
