//
//  ListFocusBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit

/// When `token` changes, it tries to focus the nearest NSTableView/NSOutlineView inside the SwiftUI List.
struct ListFocusBridge: NSViewRepresentable {
    @Binding var token: Int

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard token != context.coordinator.lastToken else { return }
        context.coordinator.lastToken = token
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if let target = self.findFirstTableLikeView(in: window.contentView) {
                window.makeFirstResponder(target)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastToken: Int = 0
    }

    private func findFirstTableLikeView(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view is NSTableView || view is NSOutlineView { return view }
        for sub in view.subviews {
            if let found = findFirstTableLikeView(in: sub) { return found }
        }
        return nil
    }
}
