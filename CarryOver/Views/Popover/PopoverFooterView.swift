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
