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
                    onMultiLinePaste: { lines in viewModel.addTasksFromPaste(lines) }
                )
                .frame(height: 40)

                Divider()
                    .padding(.top, 12)
            }
        }
    }
}
