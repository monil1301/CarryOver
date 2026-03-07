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
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // When token changes, focus the list (best-effort)
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            // Find the first NSTableView or NSOutlineView in the window and focus it
            if let target = findFirstTableLikeView(in: window.contentView) {
                window.makeFirstResponder(target)
            }
        }
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
