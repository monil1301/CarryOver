//
//  InlineDatePickerView.swift
//  CarryOver
//

import SwiftUI

struct InlineDatePickerView: View {
    @Binding var selectedDate: Date
    let onDismiss: () -> Void
    var isKeyBridgeActive: Bool = true

    @EnvironmentObject var store: DailyStore
    @State private var displayedMonth: Date = Date()
    @State private var focusedDate: Date? = nil

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var effectiveTodayStart: Date {
        calendar.startOfDay(for: store.effectiveNow())
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month/year header with navigation
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.bordered)

                Spacer()

                Text(monthYearString)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.bordered)
                    .disabled(isCurrentMonth)
            }

            // Weekday labels
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }

            // Date grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInGrid, id: \.id) { day in
                    if day.isPlaceholder {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        dateCell(day)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            displayedMonth = calendar.startOfMonth(for: selectedDate)
            focusedDate = selectedDate
        }
        .background(
            DatePickerKeyBridge(
                isOpen: isKeyBridgeActive,
                onClose: onDismiss,
                onArrow: { delta in moveFocus(byDays: delta) },
                onShiftMonth: { delta in shiftMonthAndFocus(delta) },
                onConfirm: { confirmFocus() }
            )
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Date Cell

    private func dateCell(_ day: DayInfo) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = store.dayKey(for: day.date) == store.todayKey
        let isFuture = day.date > effectiveTodayStart
        let isOtherMonth = !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month)
        let isFocused = focusedDate != nil && calendar.isDate(day.date, inSameDayAs: focusedDate!)

        return Button {
            if !isFuture && !isOtherMonth {
                selectedDate = day.date
                onDismiss()
            }
        } label: {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundColor(
                    isSelected ? .white :
                    isOtherMonth ? Color.secondary.opacity(0.3) :
                    isFuture ? Color.secondary.opacity(0.5) :
                    isToday ? .accentColor :
                    .primary
                )
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : isToday ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .opacity(isFocused && !isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .disabled(isFuture || isOtherMonth)
    }

    // MARK: - Grid computation

    private struct DayInfo: Identifiable {
        let id: Int
        let date: Date
        let isPlaceholder: Bool
    }

    private var daysInGrid: [DayInfo] {
        let start = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [DayInfo] = []

        for i in 0..<leadingBlanks {
            days.append(DayInfo(id: -(i + 1), date: Date.distantPast, isPlaceholder: true))
        }

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                days.append(DayInfo(id: day, date: date, isPlaceholder: false))
            }
        }

        return days
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: store.effectiveNow(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func shiftMonthAndFocus(_ delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        if delta > 0 && calendar.isDate(displayedMonth, equalTo: store.effectiveNow(), toGranularity: .month) { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            displayedMonth = newMonth
        }
        // Move focus to same day-of-month in the new month, clamped to today
        let base = focusedDate ?? selectedDate
        let day = calendar.component(.day, from: base)
        let newMonthRange = calendar.range(of: .day, in: .month, for: newMonth)!
        let clampedDay = min(day, newMonthRange.upperBound - 1)
        if var comps = Optional(calendar.dateComponents([.year, .month], from: newMonth)) {
            comps.day = clampedDay
            if let newFocus = calendar.date(from: comps) {
                let today = effectiveTodayStart
                focusedDate = newFocus > today ? today : newFocus
            }
        }
    }

    private func moveFocus(byDays delta: Int) {
        let base = focusedDate ?? selectedDate
        guard let newDate = calendar.date(byAdding: .day, value: delta, to: base) else { return }
        if newDate > effectiveTodayStart { return }
        focusedDate = newDate
        if !calendar.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
            withAnimation(.easeInOut(duration: 0.15)) {
                displayedMonth = calendar.startOfMonth(for: newDate)
            }
        }
    }

    private func confirmFocus() {
        guard let date = focusedDate else { return }
        if date > effectiveTodayStart { return }
        selectedDate = date
        onDismiss()
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
