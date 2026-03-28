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

    var body: some Scene {
        Settings {
            SettingsView(updater: appDelegate.updater) {
                appDelegate.reloadHotKey()
            }
        }
    }
}
