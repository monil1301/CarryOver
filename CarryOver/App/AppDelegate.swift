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

    let updateAvailable = UpdateAvailableViewModel()
    private(set) lazy var updaterDelegate: UpdaterDelegate = UpdaterDelegate(updateAvailable: updateAvailable)
    private(set) lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: updaterDelegate, userDriverDelegate: updaterDelegate
        )
        updateAvailable.updater = controller.updater
        return controller
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyService.registerDefaults()
        store.load()

        _ = updaterController // ensure initialized

        let vm = PopoverViewModel(store: store)
        viewModel = vm

        let view = PopoverRootView(viewModel: vm)
            .environmentObject(store)
            .environmentObject(updateAvailable)

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
