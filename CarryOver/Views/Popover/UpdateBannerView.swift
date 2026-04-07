//
//  UpdateBannerView.swift
//  CarryOver
//

import SwiftUI

struct UpdateBannerView: View {
    let state: UpdateState
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .available(let version):
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                Text("CarryOver **v\(version)** available")
                Spacer()
                Button("Update") { onUpdate() }
                    .buttonStyle(.borderless)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.blue)

            case .downloading:
                ProgressView()
                    .controlSize(.small)
                Text("Downloading update…")
                    .foregroundStyle(.secondary)
                Spacer()

            case .readyToInstall:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Installing…")
                    .foregroundStyle(.secondary)
                Spacer()

            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Retry") { onUpdate() }
                    .buttonStyle(.borderless)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}
