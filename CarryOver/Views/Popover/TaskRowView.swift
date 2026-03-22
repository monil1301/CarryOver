//
//  TaskRowView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var isEditing: Bool = false
    var isSelected: Bool = false
    var isToday: Bool = false
    @Binding var editText: String
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var isHovered = false

    private var showDragHandle: Bool {
        isToday && !task.isDone && !isEditing && (isHovered || isSelected)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .onTapGesture { onToggle() }

            if isEditing {
                TextField("Task", text: $editText)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { onCommitEdit() }
                    .onExitCommand { onCancelEdit() }
                    .onAppear { fieldFocused = true }
                    .onChange(of: fieldFocused) { focused in
                        if !focused && isEditing { onCancelEdit() }
                    }
            } else {
                Text(task.text)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
            }

            Spacer()

            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
        }
    }
}
