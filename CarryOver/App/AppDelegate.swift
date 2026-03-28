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
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var updater: SPUUpdater { updaterController.updater }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyService.registerDefaults()
        store.load()

        let vm = PopoverViewModel(store: store)
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

}
