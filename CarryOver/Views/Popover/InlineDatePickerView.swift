//
//  InlineDatePickerView.swift
//  CarryOver
//

import SwiftUI

struct InlineDatePickerView: View {
    @Binding var selectedDate: Date
    let onDismiss: () -> Void

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

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
                ForEach(weekdaySymbols, id: \.self) { symbol in
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
        }
    }

    // MARK: - Date Cell

    private func dateCell(_ day: DayInfo) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day.date)
        let isFuture = day.date > calendar.startOfDay(for: Date())
        let isOtherMonth = !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month)

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
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
