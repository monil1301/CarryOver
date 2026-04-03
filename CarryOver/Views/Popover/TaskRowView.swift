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
    var isCarried: Bool = false
    var isReorderable: Bool = true
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
        isReorderable && isToday && !task.isDone && !isEditing && (isHovered || isSelected)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(task.isDone ? .blue : Color.gray.opacity(0.4))
                .onTapGesture { onToggle() }

            if isEditing {
                TextField("Task", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .focused($fieldFocused)
                    .onSubmit { onCommitEdit() }
                    .onExitCommand { onCancelEdit() }
                    .onAppear { fieldFocused = true }
                    .onChange(of: fieldFocused) { focused in
                        if !focused && isEditing { onCancelEdit() }
                    }
            } else {
                Text(task.text)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
            }

            Spacer()

            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isCarried && !task.isDone {
                HStack(spacing: 3) {
                    Text("↩")
                    Text("carried")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.15), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
        }
    }
}
