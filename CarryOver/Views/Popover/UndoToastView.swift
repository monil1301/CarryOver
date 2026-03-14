//
//  UndoToastView.swift
//  CarryOver
//
//  Created by Monil Shah on 14/03/26.
//

import SwiftUI

struct UndoToastView: View {
    let label: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    var duration: Double = 4.0

    @State private var progress: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 14, height: 14)
                .foregroundStyle(.secondary)

            Text(label)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Button("Undo") { onUndo() }
                .buttonStyle(.borderless)
                .font(.callout.weight(.medium))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            progress = 1.0
            withAnimation(.linear(duration: duration)) {
                progress = 0.0
            }
        }
        .onChange(of: label) {
            progress = 1.0
            withAnimation(.linear(duration: duration)) {
                progress = 0.0
            }
        }
    }
}
