//
//  LaterView.swift
//  CarryOver
//

import SwiftUI
import UniformTypeIdentifiers

struct LaterView: View {
    @ObservedObject var viewModel: PopoverViewModel

    private let rowInsets = EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)

    private var displayedTasks: [TaskItem] {
        viewModel.isLaterSearchActive ? viewModel.laterSearchResults : viewModel.laterTasks
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLaterSearchActive {
                SearchFieldBridge(
                    text: $viewModel.laterSearchQuery,
                    focusToken: $viewModel.laterSearchFocusToken,
                    placeholder: "Filter tasks",
                    onEsc: { viewModel.handleLaterSearchEsc() },
                    onMoveToList: { viewModel.laterFocusList() }
                )
                .frame(height: 40)
                .padding(.horizontal, 16)
            }

            List(selection: $viewModel.laterSelection) {
                let tasks = displayedTasks
                if tasks.isEmpty {
                    Text(viewModel.isLaterSearchActive && !viewModel.laterSearchQuery.isEmpty
                         ? "No matching tasks"
                         : "No tasks in Later.")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(tasks) { task in
                        LaterTaskRowView(
                            task: task,
                            isEditing: viewModel.laterEditingTaskID == task.id,
                            isSelected: viewModel.laterSelection == task.id,
                            editText: $viewModel.laterEditText,
                            onComplete: { viewModel.completeLaterTask(taskID: task.id) },
                            onMoveToToday: { viewModel.moveSelectedLaterToToday(taskID: task.id) },
                            onEdit: { viewModel.startLaterEditing(taskID: task.id) },
                            onCommitEdit: { viewModel.commitLaterEdit() },
                            onCancelEdit: { viewModel.cancelLaterEdit() },
                            onDelete: { viewModel.deleteLaterTask(taskID: task.id) },
                            onSelect: { viewModel.laterSelection = task.id }
                        )
                        .tag(task.id)
                        .opacity(viewModel.laterDraggingTaskID == task.id ? 0.3 : 1.0)
                        .onDrag {
                            viewModel.beginLaterDrag(taskID: task.id)
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
                        .onDrop(of: [.text], delegate: LaterReorderDropDelegate(
                            targetTaskID: task.id,
                            viewModel: viewModel
                        ))
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 10)
            .onDeleteCommand { viewModel.deleteLaterSelected() }
            .onDrop(of: [.text], isTargeted: nil) { _ in
                viewModel.endLaterDrag()
                return true
            }

            ListFocusBridge(token: $viewModel.laterFocusListToken)
                .frame(width: 0, height: 0)

            LaterListKeyBridge(
                isOpen: viewModel.isLaterOpen,
                isEditing: viewModel.isLaterEditing,
                onReturn: { viewModel.startLaterEditingSelected() },
                onMoveToToday: { viewModel.moveSelectedLaterToToday() },
                onDelete: { viewModel.deleteLaterSelected() }
            )
            .frame(width: 0, height: 0)

            ListReorderKeyBridge(
                onMoveUp: { viewModel.moveLaterSelectedTask(direction: -1) },
                onMoveDown: { viewModel.moveLaterSelectedTask(direction: 1) }
            )
            .frame(width: 0, height: 0)

            SearchKeyBridge(
                isEditing: viewModel.isLaterEditing,
                isSearchActive: viewModel.isLaterSearchActive,
                onActivate: { viewModel.openLaterSearch() },
                onClose: { viewModel.closeLaterSearch() }
            )
            .frame(width: 0, height: 0)
        }
    }
}

struct LaterReorderDropDelegate: DropDelegate {
    let targetTaskID: UUID
    let viewModel: PopoverViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedID = viewModel.laterDraggingTaskID,
              draggedID != targetTaskID else { return }

        let tasks = viewModel.laterTasks
        guard let fromIndex = tasks.firstIndex(where: { $0.id == draggedID }),
              let toIndex = tasks.firstIndex(where: { $0.id == targetTaskID }) else { return }

        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.reorderLaterTasks(fromOffsets: IndexSet(integer: fromIndex), toOffset: destination)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endLaterDrag()
        return true
    }
}
