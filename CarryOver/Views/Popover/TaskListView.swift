//
//  TaskListView.swift
//  CarryOver
//

import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        List(selection: $viewModel.selection) {
            ForEach(viewModel.undoneTasks) { task in
                TaskRowView(
                    task: task,
                    isEditing: viewModel.editingTaskID == task.id,
                    editText: $viewModel.editText,
                    onToggle: { viewModel.toggleDone(taskID: task.id) },
                    onEdit: { viewModel.startEditing(taskID: task.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: task.id) },
                    onSelect: { viewModel.selectTask(task.id) }
                )
                .tag(task.id)
            }

            if !viewModel.doneTasks.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.doneTasks) { task in
                        TaskRowView(
                            task: task,
                            isEditing: viewModel.editingTaskID == task.id,
                            editText: $viewModel.editText,
                            onToggle: { viewModel.toggleDone(taskID: task.id) },
                            onEdit: { viewModel.startEditing(taskID: task.id) },
                            onCommitEdit: { viewModel.commitEdit() },
                            onCancelEdit: { viewModel.cancelEdit() },
                            onDelete: { viewModel.deleteTask(taskID: task.id) },
                            onSelect: { viewModel.selectTask(task.id) }
                        )
                        .tag(task.id)
                    }
                }
            }

            if viewModel.tasks.isEmpty {
                Text("No tasks for this day.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset)
        .onDeleteCommand {
            viewModel.deleteSelected()
        }

        ListFocusBridge(token: $viewModel.focusListToken)
            .frame(width: 0, height: 0)

        ListReturnKeyBridge(onReturn: {
            guard !viewModel.isEditing else { return false }
            return viewModel.startEditingSelected()
        })
        .frame(width: 0, height: 0)

        ListSpaceKeyBridge(isEditing: viewModel.isEditing, onSpace: {
            viewModel.toggleSelectedDone()
        })
        .frame(width: 0, height: 0)
    }
}
