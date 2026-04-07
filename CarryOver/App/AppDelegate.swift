//
//  AppDelegate.swift
//  CarryOver
//

import AppKit
import SwiftUI
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let store = DailyStore()
    private var viewModel: PopoverViewModel?
    private var hotKey: HotKey?

    let updateAvailable = UpdateAvailableViewModel()
    private(set) lazy var selfUpdater = SelfUpdater(viewModel: updateAvailable)

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyService.registerDefaults()
        store.load()

        selfUpdater.startAutoChecks()

        let vm = PopoverViewModel(store: store)
        viewModel = vm

        let view = PopoverRootView(viewModel: vm, selfUpdater: selfUpdater)
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
