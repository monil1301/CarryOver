//
//  SettingsView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case hotkey
    case data
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:  return "General"
        case .hotkey:   return "Hotkey"
        case .data:     return "Data"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general:  return "gearshape"
        case .hotkey:   return "keyboard"
        case .data:     return "externaldrive"
        case .advanced: return "gearshape.2"
        }
    }
}

struct SettingsView: View {
    let store: DailyStore
    let selfUpdater: SelfUpdater
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
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsTab(selfUpdater: selfUpdater)
                    case .hotkey:
                        HotkeySettingsTab(onChange: onChange)
                    case .data:
                        DataSettingsTab(store: store)
                    case .advanced:
                        AdvancedSettingsTab()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(width: 400, height: 320)
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
            .foregroundStyle(isSelected ? .blue : .secondary)
            .frame(width: 64, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thickMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                    .opacity(isSelected ? 1 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
