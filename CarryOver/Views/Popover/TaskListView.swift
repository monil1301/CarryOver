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

    private let rowInsets = EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $viewModel.selection) {
                if viewModel.isSearchActive {
                    searchResultsList
                } else {
                    normalTaskList
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 10)
            .onDeleteCommand {
                viewModel.deleteSelected()
            }
            .background(ListFocusBridge(token: $viewModel.focusListToken))
            .onChange(of: viewModel.selection) { newID in
                guard let id = newID else { return }
                proxy.scrollTo(id)
            }
        }

        ListReturnKeyBridge(onReturn: {
            guard !viewModel.isEditing else { return false }
            if !viewModel.isSearchActive && viewModel.isCompletedHeaderSelected {
                withAnimation { viewModel.toggleCompletedCollapse() }
                return true
            }
            return viewModel.startEditingSelected()
        })
        .frame(width: 0, height: 0)

        ListSpaceKeyBridge(isEditing: viewModel.isEditing, onSpace: {
            if !viewModel.isSearchActive && viewModel.isCompletedHeaderSelected {
                withAnimation { viewModel.toggleCompletedCollapse() }
                return true
            }
            return withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleSelectedDone() }
        })
        .frame(width: 0, height: 0)

        if !viewModel.isSearchActive {
            ListArrowKeyBridge(
                isHeaderSelected: { viewModel.isCompletedHeaderSelected },
                isCollapsed: { viewModel.isCompletedCollapsed },
                onExpand: { withAnimation { viewModel.isCompletedCollapsed = false } },
                onCollapse: { withAnimation { viewModel.isCompletedCollapsed = true } }
            )
            .frame(width: 0, height: 0)
        }

        ListReorderKeyBridge(
            onMoveUp: { viewModel.moveSelectedTask(direction: -1) },
            onMoveDown: { viewModel.moveSelectedTask(direction: 1) }
        )
        .frame(width: 0, height: 0)

        if !viewModel.isSearchActive {
            ListTabKeyBridge(
                isEditing: viewModel.isEditing,
                onTab: { viewModel.indentSelectedTask() },
                onShiftTab: { viewModel.unindentSelectedSubtask() }
            )
            .frame(width: 0, height: 0)

            ParentCollapseArrowBridge(
                onLeftArrow: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.collapseSelectedParent() } },
                onRightArrow: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.expandSelectedParent() } }
            )
            .frame(width: 0, height: 0)
        }
    }

    // MARK: - Search results (unified flat list)

    @ViewBuilder
    private var searchResultsList: some View {
        let results = viewModel.searchResults
        if results.isEmpty {
            Text(viewModel.searchQuery.isEmpty ? "No tasks for this day." : "No matching tasks")
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
        } else {
            ForEach(results) { task in
                TaskRowView(
                    task: task,
                    isEditing: viewModel.editingTaskID == task.id,
                    isSelected: viewModel.selection == task.id,
                    isToday: viewModel.isToday,
                    isCarried: viewModel.isCarried(task),
                    isReorderable: false,
                    editText: $viewModel.editText,
                    onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: task.id) } },
                    onEdit: { viewModel.startEditing(taskID: task.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: task.id) },
                    onSelect: { viewModel.selectTask(task.id) },
                    onMoveToLater: viewModel.isToday ? { viewModel.moveTaskToLater(taskID: task.id) } : nil,
                    isSubSyntaxHintMatch: viewModel.subSyntaxHintedParentID == task.id,
                    isCollapsed: viewModel.isParentCollapsed(task.id),
                    onToggleCollapse: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleParentCollapse(task.id) } }
                )
                .tag(task.id)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Normal task list (sections)

    @ViewBuilder
    private var normalTaskList: some View {
        if viewModel.isToday {
            todayTaskList
        } else {
            pastDayTaskList
        }

        if viewModel.tasks.isEmpty && !viewModel.showLaterNudge {
            Text("No tasks for this day.")
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
        }
    }

    // Today: undone (with drag), Later nudge, Completed section (collapsible).
    @ViewBuilder
    private var todayTaskList: some View {
        ForEach(viewModel.undoneRows) { row in
            switch row {
            case .parent(let task):
                TaskRowView(
                    task: task,
                    isEditing: viewModel.editingTaskID == task.id,
                    isSelected: viewModel.selection == task.id,
                    isToday: viewModel.isToday,
                    isCarried: viewModel.isCarried(task),
                    editText: $viewModel.editText,
                    onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: task.id) } },
                    onEdit: { viewModel.startEditing(taskID: task.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: task.id) },
                    onSelect: { viewModel.selectTask(task.id) },
                    onMoveToLater: { viewModel.moveTaskToLater(taskID: task.id) },
                    onAddSubtask: { viewModel.addSubtaskFromContextMenu(parentID: task.id) },
                    isSubSyntaxHintMatch: viewModel.subSyntaxHintedParentID == task.id,
                    isCollapsed: viewModel.isParentCollapsed(task.id),
                    onToggleCollapse: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleParentCollapse(task.id) } }
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
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)

            case .subtask(_, let subtask):
                SubtaskRowView(
                    subtask: subtask,
                    isEditing: viewModel.editingTaskID == subtask.id,
                    isSelected: viewModel.selection == subtask.id,
                    editText: $viewModel.editText,
                    onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: subtask.id) } },
                    onEdit: { viewModel.startEditing(taskID: subtask.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: subtask.id) },
                    onSelect: { viewModel.selectTask(subtask.id) }
                )
                .tag(subtask.id)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
            }
        }

        if viewModel.showLaterNudge {
            VStack(spacing: 6) {
                Text("You have \(viewModel.laterCount) task\(viewModel.laterCount == 1 ? "" : "s") in Later.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button("View Later") { viewModel.openLater() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
        }

        if !viewModel.doneTasks.isEmpty {
            Divider()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: -16, bottom: 8, trailing: -16))

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
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)

            if !viewModel.isCompletedCollapsed {
                ForEach(viewModel.doneRows) { row in
                    switch row {
                    case .parent(let task):
                        TaskRowView(
                            task: task,
                            isEditing: viewModel.editingTaskID == task.id,
                            isSelected: viewModel.selection == task.id,
                            isToday: viewModel.isToday,
                            isCarried: viewModel.isCarried(task),
                            editText: $viewModel.editText,
                            onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: task.id) } },
                            onEdit: { viewModel.startEditing(taskID: task.id) },
                            onCommitEdit: { viewModel.commitEdit() },
                            onCancelEdit: { viewModel.cancelEdit() },
                            onDelete: { viewModel.deleteTask(taskID: task.id) },
                            onSelect: { viewModel.selectTask(task.id) },
                            onMoveToLater: { viewModel.moveTaskToLater(taskID: task.id) },
                            onAddSubtask: { viewModel.addSubtaskFromContextMenu(parentID: task.id) },
                            isSubSyntaxHintMatch: viewModel.subSyntaxHintedParentID == task.id,
                            isCollapsed: viewModel.isParentCollapsed(task.id),
                            onToggleCollapse: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleParentCollapse(task.id) } }
                        )
                        .tag(task.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)

                    case .subtask(_, let subtask):
                        SubtaskRowView(
                            subtask: subtask,
                            isEditing: viewModel.editingTaskID == subtask.id,
                            isSelected: viewModel.selection == subtask.id,
                            editText: $viewModel.editText,
                            onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: subtask.id) } },
                            onEdit: { viewModel.startEditing(taskID: subtask.id) },
                            onCommitEdit: { viewModel.commitEdit() },
                            onCancelEdit: { viewModel.cancelEdit() },
                            onDelete: { viewModel.deleteTask(taskID: subtask.id) },
                            onSelect: { viewModel.selectTask(subtask.id) }
                        )
                        .tag(subtask.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
    }

    // Past day: single ForEach over `tasks` in raw array order — no undone/done segregation,
    // so toggling done state doesn't shuffle rows. No drag-to-reorder (past days are read-only
    // for ordering).
    @ViewBuilder
    private var pastDayTaskList: some View {
        ForEach(viewModel.allRows) { row in
            switch row {
            case .parent(let task):
                TaskRowView(
                    task: task,
                    isEditing: viewModel.editingTaskID == task.id,
                    isSelected: viewModel.selection == task.id,
                    isToday: false,
                    isCarried: viewModel.isCarried(task),
                    editText: $viewModel.editText,
                    onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: task.id) } },
                    onEdit: { viewModel.startEditing(taskID: task.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: task.id) },
                    onSelect: { viewModel.selectTask(task.id) },
                    onMoveToLater: nil,
                    onAddSubtask: nil,
                    isSubSyntaxHintMatch: viewModel.subSyntaxHintedParentID == task.id,
                    isCollapsed: viewModel.isParentCollapsed(task.id),
                    onToggleCollapse: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleParentCollapse(task.id) } }
                )
                .tag(task.id)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)

            case .subtask(_, let subtask):
                SubtaskRowView(
                    subtask: subtask,
                    isEditing: viewModel.editingTaskID == subtask.id,
                    isSelected: viewModel.selection == subtask.id,
                    editText: $viewModel.editText,
                    onToggle: { withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDone(taskID: subtask.id) } },
                    onEdit: { viewModel.startEditing(taskID: subtask.id) },
                    onCommitEdit: { viewModel.commitEdit() },
                    onCancelEdit: { viewModel.cancelEdit() },
                    onDelete: { viewModel.deleteTask(taskID: subtask.id) },
                    onSelect: { viewModel.selectTask(subtask.id) }
                )
                .tag(subtask.id)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
            }
        }
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
