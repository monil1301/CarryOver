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
    var onMoveToLater: (() -> Void)? = nil
    var onAddSubtask: (() -> Void)? = nil
    /// When true, the row renders with a subtle accent tint to signal that it is the live
    /// match for the currently composed `:sub <parent>` query in the input.
    var isSubSyntaxHintMatch: Bool = false
    /// Whether this parent's subtasks are currently hidden. Drives the chevron direction on
    /// the progress pill.
    var isCollapsed: Bool = false
    var onToggleCollapse: (() -> Void)? = nil

    @FocusState private var fieldFocused: Bool
    @State private var isHovered = false
    @AppStorage(DisplayPreferences.showCarriedTagKey) private var showCarriedTag: Bool = true

    private var showDragHandle: Bool {
        isReorderable && isToday && !task.isDone && !isEditing && (isHovered || isSelected)
    }

    private var canShowDragHandle: Bool {
        isReorderable && isToday && !task.isDone && !isEditing
    }

    private var canShowCarriedBadge: Bool {
        isCarried && !task.isDone && showCarriedTag
    }

    private var rowBackground: Color {
        if isSubSyntaxHintMatch { return Color.accentColor.opacity(0.10) }
        if isHovered { return Color.gray.opacity(0.06) }
        return Color.clear
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

            if !task.subtasks.isEmpty {
                SubtaskProgressPill(
                    subtasks: task.subtasks,
                    isCollapsed: isCollapsed,
                    isSelected: isSelected,
                    onToggle: { onToggleCollapse?() }
                )
            }

            Spacer()

            if canShowCarriedBadge || canShowDragHandle {
                ZStack {
                    Color.clear
                    if showDragHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if canShowCarriedBadge {
                        Text("↩")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.15), lineWidth: 0.5))
                    }
                }
                .frame(width: 24)
                .padding(.horizontal, 6)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .overlay(alignment: .leading) {
            if isSubSyntaxHintMatch {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSubSyntaxHintMatch)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            if let onAddSubtask {
                Button("Add Subtask") { onAddSubtask() }
            }
            Button("Edit") { onEdit() }
            if let onMoveToLater {
                Button("Move to Later") { onMoveToLater() }
            }
            Button("Delete") { onDelete() }
        }
    }
}

/// `▸ n/m` (collapsed) or `▾ n/m` (expanded) indicator shown after a parent's label when it
/// has subtasks. Clickable to toggle collapse; muted normally, blue tint when all done.
struct SubtaskProgressPill: View {
    let subtasks: [Subtask]
    let isCollapsed: Bool
    var isSelected: Bool = false
    let onToggle: () -> Void

    private var done: Int { subtasks.filter(\.isDone).count }
    private var total: Int { subtasks.count }
    private var allDone: Bool { total > 0 && done == total }

    private var foreground: Color {
        if allDone {
            return isSelected ? .white : Color.blue.opacity(0.9)
        }
        return Color.secondary
    }

    private var capsuleFill: Color {
        if allDone {
            return isSelected ? Color.white.opacity(0.22) : Color.blue.opacity(0.15)
        }
        return Color.secondary.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
            Text("\(done)/\(total)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Capsule().fill(capsuleFill))
        .contentShape(Capsule())
        .onTapGesture { onToggle() }
    }
}
