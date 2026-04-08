//
//  GeneralSettingsTab.swift
//  CarryOver
//
//  Created by Monil Shah on 29/03/26.
//

import SwiftUI
import ServiceManagement

struct GeneralSettingsTab: View {
    let selfUpdater: SelfUpdater

    @State private var autoCheckForUpdates = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Startup
            SettingsSection("Startup") {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                            Analytics.send("settings.openAtLogin.enabled")
                        } else {
                            try? SMAppService.mainApp.unregister()
                            Analytics.send("settings.openAtLogin.disabled")
                        }
                    }
            }

            Divider()

            // MARK: Updates
            SettingsSection("Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckForUpdates)
                    .onChange(of: autoCheckForUpdates) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks")
                        if newValue {
                            selfUpdater.startAutoChecks()
                        } else {
                            selfUpdater.stopAutoChecks()
                        }
                    }

                HStack {
                    Button("Check Now") {
                        isChecking = true
                        Task {
                            await selfUpdater.checkForUpdates(userInitiated: true)
                            isChecking = false
                        }
                    }
                    .disabled(isChecking)

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

        }
        .padding(20)
    }
}
