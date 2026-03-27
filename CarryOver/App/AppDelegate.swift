//
//  AppDelegate.swift
//  CarryOver
//

import AppKit
import SwiftUI
import HotKey
internal import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let store = DailyStore()
    private var viewModel: PopoverViewModel?
    private var hotKey: HotKey?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyService.registerDefaults()
        store.load()

        let vm = PopoverViewModel(store: store, openSettings: { [weak self] in
            self?.statusBar?.hidePopover(restoreFocus: false)
            self?.openSettings()
        })
        viewModel = vm

        let view = PopoverRootView(viewModel: vm)
            .environmentObject(store)

        statusBar = StatusBarController(rootView: view, beforeShow: { [weak self] in
            self?.store.rolloverUnfinishedToToday()
            self?.store.resetToken += 1
        })
        reloadHotKey()
    }

    func reloadHotKey() {
        hotKey = nil
        let (key, modifiers) = HotkeyService.load()
        let hk = HotKey(key: key, modifiers: modifiers)
        hk.keyDownHandler = { [weak self] in
            self?.statusBar?.toggleFromHotKey()
        }
        hotKey = hk
    }

    func openSettings() {
        if let w = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView(updater: updaterController.updater) { [weak self] in
            self?.reloadHotKey()
        }

        let hosting = NSHostingController(rootView: root)

        let w = NSWindow(contentViewController: hosting)
        w.title = "CarryOver Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 360, height: 220))
        w.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }

        settingsWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
