//
//  SubtaskRowView.swift
//  CarryOver
//
//  Created by Monil Shah on 22/04/26.
//

import SwiftUI

/// Row for a one-level subtask. Indented under its parent with a thin left border that
/// visually connects adjacent subtask rows into a single group.
struct SubtaskRowView: View {
    let subtask: Subtask
    var isEditing: Bool = false
    var isSelected: Bool = false
    @Binding var editText: String
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left border: drawn on every subtask row. Stacks seamlessly with adjacent rows
            // to form one continuous line from first to last subtask.
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1.5)
                .padding(.leading, 10)
                .padding(.trailing, 10)

            HStack(spacing: 10) {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(subtask.isDone ? .blue : Color.gray.opacity(0.4))
                    .onTapGesture { onToggle() }

                if isEditing {
                    TextField("Subtask", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .medium))
                        .focused($fieldFocused)
                        .onSubmit { onCommitEdit() }
                        .onExitCommand { onCancelEdit() }
                        .onAppear { fieldFocused = true }
                        .onChange(of: fieldFocused) { focused in
                            if !focused && isEditing { onCancelEdit() }
                        }
                } else {
                    Text(subtask.text)
                        .font(.system(size: 13.5, weight: .medium))
                        .strikethrough(subtask.isDone)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
        }
    }
}
