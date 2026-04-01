//
//  PopoverRootView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import UniformTypeIdentifiers
internal import Sparkle

struct PopoverRootView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @EnvironmentObject var store: DailyStore
    @EnvironmentObject var updateAvailable: UpdateAvailableViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                PopoverHeaderView(viewModel: viewModel)
                TaskInputView(viewModel: viewModel)

                if viewModel.isSearchActive {
                    SearchFieldBridge(
                        text: $viewModel.searchQuery,
                        focusToken: $viewModel.searchFocusToken,
                        placeholder: "Filter tasks",
                        onEsc: { viewModel.handleSearchEsc() },
                        onMoveToList: { viewModel.focusList() }
                    )
                    .frame(height: 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                TaskListView(viewModel: viewModel)
                Divider()
                PopoverFooterView()
            }
            .padding()
            .animation(.easeInOut(duration: 0.15), value: viewModel.isSearchActive)

            if let undo = viewModel.pendingUndo {
                UndoToastView(
                    label: undo.label,
                    onUndo: { viewModel.performUndo() },
                    onDismiss: { viewModel.dismissUndo() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: viewModel.pendingUndo != nil)
            } else if let version = updateAvailable.availableVersion {
                UpdateBannerView(version: version) {
                    updateAvailable.updater?.checkForUpdates()
                }
                .transition(.opacity)
            }
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            viewModel.endDrag()
            return true
        }
        .onAppear { viewModel.handleAppear() }
        .onChange(of: store.resetToken) { _ in viewModel.handleReset() }
        .onChange(of: viewModel.selectedDate) { _ in viewModel.handleDateChange() }
        .onCommand(#selector(NSResponder.moveToBeginningOfParagraph(_:))) { }

        Button("") { viewModel.performUndo() }
            .keyboardShortcut("z", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)

        ListUpArrowBridge(
            shouldHandle: { viewModel.isToday || viewModel.isSearchActive },
            onUpArrow: { viewModel.handleUpArrow() }
        )
        .frame(width: 0, height: 0)

        SearchKeyBridge(
            isEditing: viewModel.isEditing,
            isSearchActive: viewModel.isSearchActive,
            onActivate: { viewModel.openSearch() }
        )
        .frame(width: 0, height: 0)
    }
}
