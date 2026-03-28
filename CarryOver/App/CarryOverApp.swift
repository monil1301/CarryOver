//
//  CarryOverApp.swift
//  CarryOver
//
//  Created by Monil Shah on 05/03/26.
//

import SwiftUI
internal import Sparkle

@main
struct CarryOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        Settings {
            SettingsView(updater: updaterController.updater) {
                appDelegate.reloadHotKey()
            }
        }
    }
}
