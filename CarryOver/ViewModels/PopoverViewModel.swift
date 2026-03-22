//
//  PopoverViewModel.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI
internal import Combine

struct UndoAction: Equatable {
    let dayKey: String
    let snapshot: DayBucket
    let label: String
    let selectionToRestore: UUID?
}

@MainActor
final class PopoverViewModel: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    static let completedHeaderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let store: DailyStore
    let openSettings: () -> Void

    var selectedDate: Date = Date() { didSet { sendChange() } }
    var newText: String = "" { didSet { sendChange() } }
    var focusToken: Int = 0 {
        didSet {
            if isEditing { cancelEdit() }
            sendChange()
        }
    }
    var selection: UUID? {
        didSet {
            if isEditing && selection != editingTaskID { cancelEdit() }
            sendChange()
        }
    }
    var focusListToken: Int = 0 { didSet { sendChange() } }
    var showDatePicker: Bool = false { didSet { sendChange() } }
    var editingTaskID: UUID? { didSet { sendChange() } }
    var editText: String = "" { didSet { sendChange() } }
    var isCompletedCollapsed: Bool = true { didSet { sendChange() } }
    var draggingTaskID: UUID? { didSet { sendChange() } }
    var dragSnapshot: DayBucket?
    var isCompletedHeaderSelected: Bool { selection == Self.completedHeaderID }

    var pendingUndo: UndoAction? { didSet { sendChange() } }
    private var undoTimer: DispatchWorkItem?

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

    func addTasksFromPaste(_ texts: [String]) {
        let key = selectedKey
        let snapshot = store.days[key, default: DayBucket()]

        store.addTasksToday(texts)

        let count = store.tasks(for: key).count - snapshot.tasks.count
        if count > 0 {
            registerUndo(UndoAction(
                dayKey: key,
                snapshot: snapshot,
                label: "\(count) tasks added",
                selectionToRestore: selection
            ))
        }

        newText = ""
        focusToken += 1
    }

    static func parsePastedTasks(_ text: String) -> [String] {
        let markerPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*•+]|\[[ xX]\]|\d+[.)]) +(.*)"#)
        let lines = text.components(separatedBy: .newlines)
        var results: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let range = NSRange(line.startIndex..., in: line)
            if let match = markerPattern.firstMatch(in: line, range: range) {
                let taskText = String(line[Range(match.range(at: 3), in: line)!])
                if !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    results.append(taskText)
                }
            } else {
                let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
                if !leadingWhitespace.isEmpty && !results.isEmpty {
                    results[results.count - 1] += "\n" + trimmed
                } else {
                    results.append(trimmed)
                }
            }
        }

        return results.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func shiftDay(_ delta: Int) {
        if isEditing { cancelEdit() }
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = d
        }
    }

    func toggleDone(taskID: UUID) {
        let key = selectedKey
        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == taskID }) {
            let label = task.isDone ? "Unmarked '\(task.text)'" : "Completed '\(task.text)'"
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: label, selectionToRestore: selection))
        }
        store.toggleDone(dayKey: key, taskID: taskID)
    }

    func toggleSelectedDone() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        toggleDone(taskID: id)
        return true
    }

    func startEditing(taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        editingTaskID = taskID
        editText = task.text
    }

    func startEditingSelected() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        startEditing(taskID: id)
        return true
    }

    func commitEdit() {
        guard let taskID = editingTaskID else { return }
        let key = selectedKey

        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == taskID }) {
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Edited '\(task.text)'", selectionToRestore: taskID))
        }

        store.updateTaskText(dayKey: key, taskID: taskID, text: editText)
        editingTaskID = nil
        editText = ""
        focusListToken += 1
    }

    func cancelEdit() {
        editingTaskID = nil
        editText = ""
        focusListToken += 1
    }

    var isEditing: Bool { editingTaskID != nil }

    func deleteSelected() {
        guard let id = selection, !isCompletedHeaderSelected else { return }
        let key = selectedKey
        let tasksBefore = store.tasks(for: key)
        let idx = tasksBefore.firstIndex(where: { $0.id == id })

        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == id }) {
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted '\(task.text)'", selectionToRestore: id))
        }

        store.deleteTask(dayKey: key, taskID: id)

        let tasksAfter = store.tasks(for: key)
        if let idx, !tasksAfter.isEmpty {
            selection = tasksAfter[min(idx, tasksAfter.count - 1)].id
        } else {
            selection = tasksAfter.first?.id
        }

        if isToday { focusToken += 1 } else { focusListToken += 1 }
    }

    func deleteTask(taskID: UUID) {
        let key = selectedKey
        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == taskID }) {
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted '\(task.text)'", selectionToRestore: selection))
        }
        store.deleteTask(dayKey: key, taskID: taskID)
    }

    func moveSelectedTask(direction: Int) -> Bool {
        guard isToday, !isEditing,
              let id = selection, !isCompletedHeaderSelected,
              let task = undoneTasks.first(where: { $0.id == id }),
              !task.isDone else { return false }

        let key = selectedKey
        let snapshot = store.days[key, default: DayBucket()]
        store.moveTask(dayKey: key, taskID: id, direction: direction)

        // Check if move actually happened
        let newTasks = store.tasks(for: key)
        if newTasks.map(\.id) != snapshot.tasks.map(\.id) {
            registerUndo(UndoAction(dayKey: key, snapshot: snapshot, label: "Moved '\(task.text)'", selectionToRestore: id))
        }
        return true
    }

    func reorderUndoneTasks(fromOffsets: IndexSet, toOffset: Int) {
        guard isToday, !isEditing else { return }
        let key = selectedKey
        store.reorderUndoneTasks(dayKey: key, fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func beginDrag(taskID: UUID) {
        let key = selectedKey
        dragSnapshot = store.days[key, default: DayBucket()]
        draggingTaskID = taskID
    }

    func endDrag() {
        guard draggingTaskID != nil else { return }
        if let snapshot = dragSnapshot, let id = draggingTaskID {
            let key = selectedKey
            if store.tasks(for: key).map(\.id) != snapshot.tasks.map(\.id) {
                registerUndo(UndoAction(dayKey: key, snapshot: snapshot, label: "Reordered tasks", selectionToRestore: id))
            }
            selection = id
        }
        draggingTaskID = nil
        dragSnapshot = nil
    }

    func toggleCompletedCollapse() {
        isCompletedCollapsed.toggle()
    }

    func focusList() {
        selection = tasks.first?.id
        focusListToken += 1
    }

    func focusInput() {
        if isToday { focusToken += 1 }
    }

    func handleReset() {
        if isEditing { cancelEdit() }
        selectedDate = Date()
        selection = nil
        focusToken += 1
    }

    func handleDateChange() {
        if isEditing { cancelEdit() }
        selection = nil
        if isToday { focusToken += 1 } else { focusList() }
    }

    func handleAppear() {
        if isEditing { cancelEdit() }
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

    // MARK: - Undo

    func registerUndo(_ action: UndoAction) {
        undoTimer?.cancel()
        pendingUndo = action
        let timer = DispatchWorkItem { [weak self] in
            self?.dismissUndo()
        }
        undoTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: timer)
    }

    func performUndo() {
        guard let action = pendingUndo else { return }
        store.restoreBucket(dayKey: action.dayKey, bucket: action.snapshot)
        if selectedKey == action.dayKey, let sel = action.selectionToRestore {
            selection = sel
        }
        dismissUndo()
    }

    func dismissUndo() {
        undoTimer?.cancel()
        undoTimer = nil
        pendingUndo = nil
    }

    private static func prettyDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "dd MMM, yy"
        return f.string(from: date)
    }
}
