//
//  PopoverViewModel.swift
//  CarryOver
//

import SwiftUI
internal import Combine

final class PopoverViewModel: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    let store: DailyStore
    let openSettings: () -> Void

    var selectedDate: Date = Date() { didSet { sendChange() } }
    var newText: String = "" { didSet { sendChange() } }
    var focusToken: Int = 0 { didSet { sendChange() } }
    var selection: UUID? { didSet { sendChange() } }
    var focusListToken: Int = 0 { didSet { sendChange() } }
    var showDatePicker: Bool = false { didSet { sendChange() } }

    private func sendChange() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var selectedKey: String { store.dayKey(for: selectedDate) }
    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(selectedDate) }

    var titleText: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        return Self.prettyDate(selectedDate)
    }

    var tasks: [TaskItem] { store.tasks(for: selectedKey) }
    var undoneTasks: [TaskItem] { tasks.filter { !$0.isDone } }
    var doneTasks: [TaskItem] { tasks.filter { $0.isDone } }

    private var storeCancellable: AnyCancellable?

    init(store: DailyStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
        storeCancellable = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func addTask() {
        store.addTaskToday(newText)
        newText = ""
        focusToken += 1
    }

    func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = d
        }
    }

    func toggleDone(taskID: UUID) {
        store.toggleDone(dayKey: selectedKey, taskID: taskID)
    }

    func deleteSelected() {
        guard let id = selection else { return }
        let tasksBefore = store.tasks(for: selectedKey)
        let idx = tasksBefore.firstIndex(where: { $0.id == id })

        store.deleteTask(dayKey: selectedKey, taskID: id)

        let tasksAfter = store.tasks(for: selectedKey)
        if let idx, !tasksAfter.isEmpty {
            selection = tasksAfter[min(idx, tasksAfter.count - 1)].id
        } else {
            selection = tasksAfter.first?.id
        }

        if isToday { focusToken += 1 } else { focusListToken += 1 }
    }

    func deleteTask(taskID: UUID) {
        store.deleteTask(dayKey: selectedKey, taskID: taskID)
    }

    func focusList() {
        selection = tasks.first?.id
        focusListToken += 1
    }

    func focusInput() {
        if isToday { focusToken += 1 }
    }

    func handleReset() {
        selectedDate = Date()
        selection = nil
        focusToken += 1
    }

    func handleDateChange() {
        selection = nil
        if isToday { focusToken += 1 } else { focusList() }
    }

    func handleAppear() {
        if isToday { focusToken += 1 } else { focusList() }
    }

    func handleUpArrow() -> Bool {
        guard let firstID = tasks.first?.id else { return false }
        if selection == nil || selection == firstID {
            selection = nil
            focusToken += 1
            return true
        }
        return false
    }

    func selectTask(_ taskID: UUID) {
        selection = taskID
        DispatchQueue.main.async { [self] in
            focusListToken += 1
        }
    }

    private static func prettyDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "dd MMM, yy"
        return f.string(from: date)
    }
}
