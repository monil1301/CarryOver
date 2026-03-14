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
            HStack(spacing: 8) {
                QuickAddTextView(
                    text: $viewModel.newText,
                    focusToken: $viewModel.focusToken,
                    placeholder: "Add a task…",
                    onCommit: { viewModel.addTask() },
                    onMoveToList: { viewModel.focusList() },
                    onMoveToInput: { viewModel.focusInput() }
                )
                .frame(height: 34)

                Button("Add", action: { viewModel.addTask() })
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        } else {
            Text("Add new tasks on Today.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
