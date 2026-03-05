//
//  CarryOverApp.swift
//  CarryOver
//
//  Created by Monil Shah on 05/03/26.
//

import SwiftUI

@main
struct CarryOverApp: App {
    var body: some Scene {
        MenuBarExtra("CarryOver", systemImage: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                Text("CarryOver")
                    .font(.headline)

                Text("Menu bar app is working ✅")
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding()
            .frame(width: 320)
        }
    }
}
