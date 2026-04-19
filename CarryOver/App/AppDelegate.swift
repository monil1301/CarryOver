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
        let rolloverResult = store.load()

        Analytics.initialize()
        Analytics.send("app.launched")
        if rolloverResult.carriedCount > 0 {
            Analytics.send("task.carriedOver", with: ["count": "\(rolloverResult.carriedCount)"])
        }

        selfUpdater.startAutoChecks()

        let vm = PopoverViewModel(store: store)
        viewModel = vm
        vm.handleRolloverResult(rolloverResult)

        let view = PopoverRootView(viewModel: vm, selfUpdater: selfUpdater)
            .environmentObject(store)
            .environmentObject(updateAvailable)

        statusBar = StatusBarController(rootView: view, beforeShow: { [weak self] in
            guard let self else { return }
            let result = self.store.rolloverUnfinishedToToday()
            self.store.resetToken += 1
            self.viewModel?.handleRolloverResult(result)
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
