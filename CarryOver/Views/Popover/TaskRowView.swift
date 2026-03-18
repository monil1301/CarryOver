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
    @Binding var editText: String
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @FocusState private var fieldFocused: Bool

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
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
        }
    }
}
