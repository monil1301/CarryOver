//
//  UpdateBannerView.swift
//  CarryOver
//

import SwiftUI

struct UpdateBannerView: View {
    let version: String
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)

            Text("CarryOver **v\(version)** available")

            Spacer()

            Button("Update") { onUpdate() }
                .buttonStyle(.borderless)
                .font(.callout.weight(.medium))
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 8)
    }
}
