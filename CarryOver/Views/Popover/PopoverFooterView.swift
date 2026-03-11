//
//  PopoverFooterView.swift
//  CarryOver
//

import SwiftUI

struct PopoverFooterView: View {
    let openSettings: () -> Void

    var body: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.bordered)
        }
    }
}
