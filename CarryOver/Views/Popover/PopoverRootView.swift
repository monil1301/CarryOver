//
//  PopoverRootView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct PopoverRootView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @EnvironmentObject var store: DailyStore
    @EnvironmentObject var updateAvailable: UpdateAvailableViewModel

    init(viewModel: PopoverViewModel, selfUpdater: SelfUpdater) {
        self.viewModel = viewModel
        self.selfUpdater = selfUpdater
    }

    private var showUndo: Bool { viewModel.pendingUndo != nil }
    private var showUpdate: Bool { !showUndo && updateAvailable.state != nil }
    private var showSlotBackground: Bool { showUndo || showUpdate }
    private let selfUpdater: SelfUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverHeaderView(
                viewModel: viewModel,
                isCheatSheetOpen: viewModel.isCheatSheetOpen,
                isLaterOpen: viewModel.isLaterOpen,
                onBack: { viewModel.closeCheatSheet() },
                onCloseLater: { viewModel.closeLater() },
                onOpenLater: { viewModel.openLater() }
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ZStack {
                // Main content
                VStack(alignment: .leading, spacing: 0) {
                    if !viewModel.showDatePicker {
                        if viewModel.isSearchActive {
                            SearchFieldBridge(
                                text: $viewModel.searchQuery,
                                focusToken: $viewModel.searchFocusToken,
                                placeholder: "Filter tasks",
                                onEsc: { viewModel.handleSearchEsc() },
                                onMoveToList: { viewModel.focusList() }
                            )
                            .frame(height: 40)
                            .padding(.horizontal, 16)
                        } else {
                            TaskInputView(viewModel: viewModel)
                                .padding(.horizontal, 16)
                        }
                    }

                    if viewModel.showDatePicker {
                        InlineDatePickerView(
                            selectedDate: $viewModel.selectedDate,
                            onDismiss: { viewModel.showDatePicker = false }
                        )
                    } else {
                        TaskListView(viewModel: viewModel)
                    }

                    Spacer(minLength: 0)

                    Divider()

                    // Fixed-height notification slot
                    ZStack {
                        if let undo = viewModel.pendingUndo {
                            UndoToastView(
                                label: undo.label,
                                onUndo: { viewModel.performUndo() },
                                onDismiss: { viewModel.dismissUndo() }
                            )
                        }

                        if let state = updateAvailable.state {
                            UpdateBannerView(state: state) {
                                Analytics.send("update.started")
                                selfUpdater.startUpdate()
                            }
                            .opacity(showUpdate ? 1 : 0)
                            .onAppear { Analytics.send("update.banner.shown") }
                        }
                    }
                    .frame(height: 38)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .background(
                        Color.gray.opacity(showSlotBackground ? 0.08 : 0)
                            .animation(.easeInOut(duration: 0.2), value: showSlotBackground)
                    )

                    Divider()

                    PopoverFooterView(onShortcutsHelp: { viewModel.toggleCheatSheet() })
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, -24)
                }

                // Cheat sheet overlay
                if viewModel.isCheatSheetOpen {
                    ShortcutsCheatSheetView(onDismiss: { viewModel.closeCheatSheet() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                        .transition(.move(edge: .trailing))
                }

                // Later overlay
                if viewModel.isLaterOpen {
                    LaterView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isCheatSheetOpen)
        .animation(.easeOut(duration: 0.2), value: viewModel.isLaterOpen)
        .animation(.easeInOut(duration: 0.15), value: viewModel.isSearchActive)
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
            onActivate: { viewModel.openSearch() },
            onClose: { viewModel.closeSearch() }
        )
        .frame(width: 0, height: 0)

        CheatSheetKeyBridge(
            isOpen: viewModel.isCheatSheetOpen,
            onToggle: { viewModel.toggleCheatSheet() },
            onClose: { viewModel.closeCheatSheet() }
        )
        .frame(width: 0, height: 0)

        LaterKeyBridge(
            isOpen: viewModel.isLaterOpen,
            isEditing: viewModel.isLaterEditing,
            onToggle: { viewModel.toggleLater() },
            onClose: { viewModel.closeLater() },
            onMoveToLater: { viewModel.moveSelectedToLater() }
        )
        .frame(width: 0, height: 0)
    }
}
