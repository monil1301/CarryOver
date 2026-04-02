//
//  PopoverRootView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI
internal import Sparkle

struct PopoverRootView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @EnvironmentObject var store: DailyStore
    @EnvironmentObject var updateAvailable: UpdateAvailableViewModel

    private var showUndo: Bool { viewModel.pendingUndo != nil }
    private var showUpdate: Bool { !showUndo && updateAvailable.availableVersion != nil }
    private var showSlotBackground: Bool { showUndo || showUpdate }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverHeaderView(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if !viewModel.showDatePicker {
                TaskInputView(viewModel: viewModel)
                    .padding(.horizontal, 16)
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

                if let version = updateAvailable.availableVersion {
                    UpdateBannerView(version: version) {
                        updateAvailable.updater?.checkForUpdates()
                    }
                    .opacity(showUpdate ? 1 : 0)
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

            PopoverFooterView()
                .padding(.horizontal, 16)
                .padding(.top, 10)
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
            shouldHandle: { viewModel.isToday },
            onUpArrow: { viewModel.handleUpArrow() }
        )
        .frame(width: 0, height: 0)
    }
}
