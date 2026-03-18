//
//  PopoverHeaderView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI

struct PopoverHeaderView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(viewModel.titleText)
                .font(.headline)

            Spacer()

            Button {
                viewModel.selectedDate = Date()
                viewModel.focusToken += 1
            } label: {
                Text("Today")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("t", modifiers: [.command])

            HStack(spacing: 6) {
                Button { viewModel.shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered)
                .help("Previous day")
                .keyboardShortcut("[", modifiers: [.command])

                Button { viewModel.shiftDay(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
                .help("Next day")
                .keyboardShortcut("]", modifiers: [.command])

                Button { viewModel.showDatePicker.toggle() } label: { Image(systemName: "calendar") }
                .buttonStyle(.bordered)
                .help("Pick a date")
                .keyboardShortcut("p", modifiers: [.command])
                .popover(isPresented: $viewModel.showDatePicker, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker(
                            "Date",
                            selection: $viewModel.selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)

                        HStack {
                            Spacer()
                            Button("Done") { viewModel.showDatePicker = false }
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding()
                    .frame(width: 320)
                }
            }
        }
    }
}
