//
//  PopoverHeaderView.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI

struct PopoverHeaderView: View {
    @ObservedObject var viewModel: PopoverViewModel
    var isCheatSheetOpen: Bool = false
    var onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                if isCheatSheetOpen {
                    Button { onBack?() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Text("Shortcuts")
                        .font(.system(size: 20, weight: .bold))
                } else {
                    Text(viewModel.titleText)
                        .font(.system(size: 20, weight: .bold))
                }

                Spacer()

                if !isCheatSheetOpen {
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
                    }
                }
            }

            if !isCheatSheetOpen {
                Text(viewModel.dateSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
