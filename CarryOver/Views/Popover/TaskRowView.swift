//
//  TaskRowView.swift
//  CarryOver
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .onTapGesture { onToggle() }

            Text(task.text)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? .secondary : .primary)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Delete") { onDelete() }
        }
    }
}
