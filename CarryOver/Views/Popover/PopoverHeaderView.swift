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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.titleText)
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                HStack(spacing: 6) {
                    Button { viewModel.shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.bordered)
                        .help("Previous day")
                        .keyboardShortcut("[", modifiers: [.command])

                    if !viewModel.isToday {
                        Button {
                            viewModel.selectedDate = Date()
                            viewModel.focusToken += 1
                        } label: {
                            Text("Today")
                        }
                        .buttonStyle(.bordered)
                        .frame(minWidth: 56)
                        .keyboardShortcut("t", modifiers: [.command])
                    }

                    Button { viewModel.shiftDay(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.bordered)
                        .help("Next day")
                        .keyboardShortcut("]", modifiers: [.command])
                        .disabled(viewModel.isToday)

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

            Text(viewModel.dateSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
