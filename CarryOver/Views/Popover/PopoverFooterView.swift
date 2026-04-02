//
//  PopoverFooterView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI

struct PopoverFooterView: View {
    var body: some View {
        HStack {
            SettingsLink {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }
}
