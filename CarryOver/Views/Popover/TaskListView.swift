//
//  TaskListView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
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
                if viewModel.isToday {
                    Divider()
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(viewModel.isCompletedCollapsed ? 0 : 90))
                            .font(.caption2)
                        Text("Completed (\(viewModel.doneTasks.count))")
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline.weight(.medium))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selection = PopoverViewModel.completedHeaderID
                        withAnimation { viewModel.toggleCompletedCollapse() }
                    }
                    .tag(PopoverViewModel.completedHeaderID)
                }

                if !viewModel.isToday || !viewModel.isCompletedCollapsed {
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
            if viewModel.isCompletedHeaderSelected {
                withAnimation { viewModel.toggleCompletedCollapse() }
                return true
            }
            return viewModel.startEditingSelected()
        })
        .frame(width: 0, height: 0)

        ListSpaceKeyBridge(isEditing: viewModel.isEditing, onSpace: {
            if viewModel.isCompletedHeaderSelected {
                withAnimation { viewModel.toggleCompletedCollapse() }
                return true
            }
            return viewModel.toggleSelectedDone()
        })
        .frame(width: 0, height: 0)

        ListArrowKeyBridge(
            isHeaderSelected: { viewModel.isCompletedHeaderSelected },
            isCollapsed: { viewModel.isCompletedCollapsed },
            onExpand: { withAnimation { viewModel.isCompletedCollapsed = false } },
            onCollapse: { withAnimation { viewModel.isCompletedCollapsed = true } }
        )
        .frame(width: 0, height: 0)
    }
}
