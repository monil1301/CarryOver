//
//  GeneralSettingsTab.swift
//  CarryOver
//
//  Created by Monil Shah on 29/03/26.
//

import SwiftUI
import ServiceManagement
internal import Sparkle

struct GeneralSettingsTab: View {
    let updater: SPUUpdater

    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    @State private var autoCheckForUpdates = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Startup
            SettingsSection("Startup") {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }

            Divider()

            // MARK: Updates
            SettingsSection("Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckForUpdates)
                    .onAppear { autoCheckForUpdates = updater.automaticallyChecksForUpdates }
                    .onChange(of: autoCheckForUpdates) { newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }

                HStack {
                    Button("Check Now") {
                        updater.checkForUpdates()
                    }
                    .disabled(!checkForUpdatesViewModel.canCheckForUpdates)

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
