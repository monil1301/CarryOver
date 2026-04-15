//
//  ListFocusBridge.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import AppKit

/// When `token` changes, it tries to focus the nearest NSTableView/NSOutlineView inside the SwiftUI List.
/// Place as a `.background()` on the List so the bridge shares the same hosting subtree.
struct ListFocusBridge: NSViewRepresentable {
    @Binding var token: Int

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard token != context.coordinator.lastToken else { return }
        context.coordinator.lastToken = token
        Self.focusTable(in: nsView, attempt: 0)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastToken: Int = 0
    }

    private static func focusTable(in nsView: NSView, attempt: Int) {
        // First attempt fires immediately; retries use a real delay so the
        // hosting hierarchy has time to finish setting up the NSTableView.
        let block = {
            guard let window = nsView.window else {
                if attempt < 3 { focusTable(in: nsView, attempt: attempt + 1) }
                return
            }
            if let target = findTableViaAncestors(of: nsView) {
                window.makeFirstResponder(target)
            } else if attempt < 3 {
                focusTable(in: nsView, attempt: attempt + 1)
            }
        }

        if attempt == 0 {
            DispatchQueue.main.async { block() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { block() }
        }
    }

    /// Walk up the ancestor chain from `view`, searching each ancestor's subtree
    /// for an NSTableView/NSOutlineView. Because the bridge is placed as a
    /// `.background()` on the List, it shares the same hosting subtree — the
    /// nearest table found is always the correct one.
    private static func findTableViaAncestors(of view: NSView) -> NSView? {
        var ancestor: NSView? = view.superview
        while let current = ancestor {
            if let table = findFirstTableLikeView(in: current) {
                return table
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func findFirstTableLikeView(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view is NSTableView || view is NSOutlineView { return view }
        for sub in view.subviews {
            if let found = findFirstTableLikeView(in: sub) { return found }
        }
        return nil
    }
}
