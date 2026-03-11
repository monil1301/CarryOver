//
//  CarryOverApp.swift
//  CarryOver
//
//  Created by Monil Shah on 05/03/26.
//

import SwiftUI

@main
struct CarryOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView {
                appDelegate.reloadHotKey()
            }
        }
    }
}
