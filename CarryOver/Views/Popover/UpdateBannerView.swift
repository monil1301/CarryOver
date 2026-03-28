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
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)

            Text("CarryOver \(version) available")
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Button("Update") { onUpdate() }
                .buttonStyle(.borderless)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
