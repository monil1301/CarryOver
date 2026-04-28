//
//  TaskInputView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI

struct TaskInputView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        if viewModel.isToday {
            VStack(spacing: 0) {
                QuickAddTextView(
                    text: $viewModel.newText,
                    focusToken: $viewModel.focusToken,
                    placeholder: "Add a task…",
                    onCommit: { viewModel.addTask() },
                    onMoveToList: { viewModel.focusList() },
                    onMoveToInput: { viewModel.focusInput() },
                    onMultiLinePaste: { lines in viewModel.addTasksFromPaste(lines) },
                    onTabComplete: { viewModel.completeSubSyntax() },
                    onDragEndedOverInput: { viewModel.endDrag() }
                )
                .frame(height: 40)

                if let hint = viewModel.subSyntaxHint {
                    SubSyntaxHintView(hint: hint)
                }

                Divider()
                    .padding(.top, 12)
            }
        }
    }
}

/// Autocomplete hint row shown under the input while the user is composing `<text> :sub <parent>`.
/// Mirrors the lightweight footer vibe — muted colors, small font, no borders.
private struct SubSyntaxHintView: View {
    let hint: SubSyntaxHint

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            if let parent = hint.parentMatch {
                Text(parent.text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text("⇥ Tab to complete")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text(hint.rawQuery.isEmpty ? "Type parent task name" : "No matching task")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
    }
}
