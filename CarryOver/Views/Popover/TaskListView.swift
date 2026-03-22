//
//  TaskListView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        List(selection: $viewModel.selection) {
            ForEach(viewModel.undoneTasks) { task in
                TaskRowView(
                    task: task,
                    isEditing: viewModel.editingTaskID == task.id,
                    isSelected: viewModel.selection == task.id,
                    isToday: viewModel.isToday,
                    editText: $viewModel.editText,
                    onToggle: { viewModel.toggleDone(taskID: task.id) },
                    onEdit: { viewModel.startEditing(taskID: task.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: task.id) },
                    onSelect: { viewModel.selectTask(task.id) }
                )
                .tag(task.id)
                .opacity(viewModel.draggingTaskID == task.id ? 0.3 : 1.0)
                .onDrag {
                    viewModel.beginDrag(taskID: task.id)
                    return NSItemProvider(object: task.id.uuidString as NSString)
                } preview: {
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                        Text(task.text)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 280, alignment: .leading)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                }
                .onDrop(of: [.text], delegate: TaskReorderDropDelegate(
                    targetTaskID: task.id,
                    viewModel: viewModel
                ))
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
                            isSelected: viewModel.selection == task.id,
                            isToday: viewModel.isToday,
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

        ListReorderKeyBridge(
            onMoveUp: { viewModel.moveSelectedTask(direction: -1) },
            onMoveDown: { viewModel.moveSelectedTask(direction: 1) }
        )
        .frame(width: 0, height: 0)
    }
}

struct TaskReorderDropDelegate: DropDelegate {
    let targetTaskID: UUID
    let viewModel: PopoverViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedID = viewModel.draggingTaskID,
              draggedID != targetTaskID else { return }

        let undone = viewModel.undoneTasks
        guard let fromIndex = undone.firstIndex(where: { $0.id == draggedID }),
              let toIndex = undone.firstIndex(where: { $0.id == targetTaskID }) else { return }

        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.reorderUndoneTasks(fromOffsets: IndexSet(integer: fromIndex), toOffset: destination)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag()
        return true
    }
}
