//
//  LaterTaskRowView.swift
//  CarryOver
//

import SwiftUI

struct LaterTaskRowView: View {
    let task: TaskItem
    var isEditing: Bool = false
    var isSelected: Bool = false
    @Binding var editText: String
    let onComplete: () -> Void
    let onMoveToToday: () -> Void
    let onEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.gray.opacity(0.4))
                .onTapGesture { onComplete() }

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
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Move to Today") { onMoveToToday() }
            Button("Edit") { onEdit() }
            Divider()
            Button("Delete") { onDelete() }
        }
    }
}
