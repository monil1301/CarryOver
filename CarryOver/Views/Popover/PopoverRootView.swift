//
//  PopoverRootView.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @EnvironmentObject var store: DailyStore

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                PopoverHeaderView(viewModel: viewModel)
                TaskInputView(viewModel: viewModel)
                TaskListView(viewModel: viewModel)
                Divider()
                PopoverFooterView(openSettings: viewModel.openSettings)
            }
            .padding()

            if let undo = viewModel.pendingUndo {
                UndoToastView(
                    label: undo.label,
                    onUndo: { viewModel.performUndo() },
                    onDismiss: { viewModel.dismissUndo() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 44)
                .animation(.easeInOut(duration: 0.2), value: viewModel.pendingUndo != nil)
            }
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
