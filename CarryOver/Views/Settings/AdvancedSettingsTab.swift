//
//  AdvancedSettingsTab.swift
//  CarryOver
//

import SwiftUI

struct AdvancedSettingsTab: View {
    @State private var threshold: Int = RolloverPreferences.currentThreshold()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Rollover") {
                Picker("Auto-move to Later after", selection: $threshold) {
                    ForEach(RolloverPreferences.options, id: \.self) { days in
                        Text(RolloverPreferences.label(for: days)).tag(days)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: threshold) { newValue in
                    UserDefaults.standard.set(newValue, forKey: RolloverPreferences.autoMoveToLaterDaysKey)
                    Analytics.send("settings.autoMoveToLater.changed", with: ["value": "\(newValue)"])
                }

                Text("Tasks older than this threshold will automatically move to Later during daily rollover.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}
