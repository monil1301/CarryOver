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
        VStack(alignment: .leading, spacing: 12) {
            PopoverHeaderView(viewModel: viewModel)
            TaskInputView(viewModel: viewModel)
            TaskListView(viewModel: viewModel)
            Divider()
            PopoverFooterView(openSettings: viewModel.openSettings)
        }
        .padding()
        .onAppear { viewModel.handleAppear() }
        .onChange(of: store.resetToken) { _ in viewModel.handleReset() }
        .onChange(of: viewModel.selectedDate) { _ in viewModel.handleDateChange() }
        .onCommand(#selector(NSResponder.moveToBeginningOfParagraph(_:))) { }

        ListUpArrowBridge(
            shouldHandle: { viewModel.isToday },
            onUpArrow: { viewModel.handleUpArrow() }
        )
        .frame(width: 0, height: 0)
    }
}
