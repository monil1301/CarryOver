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
    var isLaterOpen: Bool = false
    var onBack: (() -> Void)?
    var onCloseLater: (() -> Void)?
    var onOpenLater: (() -> Void)?

    private var showOverlay: Bool { isCheatSheetOpen || isLaterOpen }

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
                } else if isLaterOpen {
                    Button { onCloseLater?() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Text("Later")
                        .font(.system(size: 20, weight: .bold))
                } else {
                    Text(viewModel.titleText)
                        .font(.system(size: 20, weight: .bold))
                }

                Spacer()

                if !showOverlay {
                    HStack(spacing: 6) {
                        Button { viewModel.shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.bordered)
                            .help("Previous day")
                            .keyboardShortcut("[", modifiers: [.command])

                        Button {
                            viewModel.selectedDate = viewModel.store.effectiveNow()
                            viewModel.focusToken += 1
                        } label: {
                            Text("Today")
                        }
                        .buttonStyle(.bordered)
                        .frame(minWidth: 56)
                        .keyboardShortcut("t", modifiers: [.command])
                        .disabled(viewModel.isToday)

                        Button { viewModel.shiftDay(1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.bordered)
                            .help("Next day")
                            .keyboardShortcut("]", modifiers: [.command])
                            .disabled(viewModel.isToday)

                        Button {
                        if !viewModel.showDatePicker { Analytics.send("datePicker.opened") }
                        viewModel.showDatePicker.toggle()
                    } label: { Image(systemName: "calendar") }
                            .buttonStyle(.bordered)
                            .help("Pick a date")
                            .keyboardShortcut("p", modifiers: [.command])
                    }
                }
            }

            if !showOverlay {
                HStack {
                    Text(viewModel.dateSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if viewModel.hasLaterTasks {
                        Button { onOpenLater?() } label: {
                            HStack(spacing: 2) {
                                Text("Later (\(viewModel.laterCount))")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
