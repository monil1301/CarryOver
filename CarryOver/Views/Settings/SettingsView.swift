//
//  SettingsView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
internal import Sparkle

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case hotkey
    // Future tabs:
    // case data
    // case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:  return "General"
        case .hotkey:   return "Hotkey"
        }
    }

    var icon: String {
        switch self {
        case .general:  return "gearshape"
        case .hotkey:   return "keyboard"
        }
    }
}

struct SettingsView: View {
    let updater: SPUUpdater
    let onChange: () -> Void

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar-style tab picker
            HStack(spacing: 20) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(updater: updater)
                case .hotkey:
                    HotkeySettingsTab(onChange: onChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 400, height: 280)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "CarryOver Settings" }?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// MARK: - Tab Button

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                Text(tab.label)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(width: 64, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
