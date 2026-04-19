//
//  AdvancedSettingsTab.swift
//  CarryOver
//

import SwiftUI

struct AdvancedSettingsTab: View {
    @State private var threshold: Int = RolloverPreferences.currentThreshold()
    @State private var cutoffHour: Int = RolloverPreferences.currentCutoffHour()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Rollover") {
                Picker("Rollover cutoff time", selection: $cutoffHour) {
                    ForEach(RolloverPreferences.cutoffHourOptions, id: \.self) { hour in
                        Text(RolloverPreferences.cutoffLabel(for: hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: cutoffHour) { newValue in
                    UserDefaults.standard.set(newValue, forKey: RolloverPreferences.cutoffHourKey)
                    Analytics.send("settings.rolloverCutoffHour.changed", with: ["value": "\(newValue)"])
                }

                Text("Unfinished tasks roll over at this time. Pick a later hour if you work past midnight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
