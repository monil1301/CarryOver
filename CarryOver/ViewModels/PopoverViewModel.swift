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

    // Search state
    var isSearchActive: Bool = false { didSet { sendChange() } }
    var searchQuery: String = "" { didSet { sendChange() } }
    var searchFocusToken: Int = 0 { didSet { sendChange() } }
    private var searchSessionPinnedIDs: Set<UUID> = []

    // Cheat sheet state
    var isCheatSheetOpen: Bool = false { didSet { sendChange() } }

    // Later state
    var isLaterOpen: Bool = false { didSet { sendChange() } }
    var laterSelection: UUID? {
        didSet {
            if isLaterEditing && laterSelection != laterEditingTaskID { cancelLaterEdit() }
            sendChange()
        }
    }
    var laterEditingTaskID: UUID? { didSet { sendChange() } }
    var laterEditText: String = "" { didSet { sendChange() } }
    var laterFocusListToken: Int = 0 { didSet { sendChange() } }
    var laterDraggingTaskID: UUID? { didSet { sendChange() } }
    private var laterDragSnapshot: [TaskItem]?
    var isLaterSearchActive: Bool = false { didSet { sendChange() } }
    var laterSearchQuery: String = "" { didSet { sendChange() } }
    var laterSearchFocusToken: Int = 0 { didSet { sendChange() } }

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
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMM d"
        return f.string(from: selectedDate)
    }

    var tasks: [TaskItem] { store.tasks(for: selectedKey) }
    var undoneTasks: [TaskItem] { tasks.filter { !$0.isDone } }
    var doneTasks: [TaskItem] { tasks.filter { $0.isDone } }

    var dateSubtitle: String {
        let f = DateFormatter()
        f.locale = Locale.current
        if isToday || isYesterday {
            f.dateFormat = "EEEE, MMMM d"
        } else {
            f.dateFormat = "EEEE"
        }
        return f.string(from: selectedDate)
    }

    func isCarried(_ task: TaskItem) -> Bool {
        guard isToday else { return false }
        return !Calendar.current.isDateInToday(task.createdAt)
    }

    var laterTasks: [TaskItem] { store.laterTasks }
    var laterCount: Int { store.laterTasks.count }
    var hasLaterTasks: Bool { !store.laterTasks.isEmpty }
    var isLaterEditing: Bool { laterEditingTaskID != nil }

    var laterSearchResults: [TaskItem] {
        let q = laterSearchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return laterTasks }
        return laterTasks.filter { $0.text.lowercased().contains(q) }
    }
    var showLaterNudge: Bool { isToday && undoneTasks.isEmpty && hasLaterTasks }

    var searchResults: [TaskItem] {
        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        return tasks.filter { task in
            searchSessionPinnedIDs.contains(task.id) ||
            q.isEmpty ||
            task.text.lowercased().contains(q)
        }
    }

    private var storeCancellable: AnyCancellable?

    init(store: DailyStore) {
        self.store = store
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
        Analytics.send("task.added")
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
        Analytics.send("pasteAsTasks.used")
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
        if isSearchActive { closeSearch() }
        if isLaterOpen { closeLater() }
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = d
        }
        if delta < 0 { Analytics.send("dayNavigator.previousDay") }
    }

    func toggleDone(taskID: UUID) {
        let key = selectedKey
        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == taskID }) {
            let label = task.isDone ? "Unmarked '\(task.text)'" : "Completed '\(task.text)'"
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: label, selectionToRestore: selection))
            if !task.isDone { Analytics.send("task.completed") }
        }
        store.toggleDone(dayKey: key, taskID: taskID)
        pinTaskInSearch(taskID)
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
        pinTaskInSearch(taskID)
        editingTaskID = nil
        editText = ""
        focusListToken += 1
        Analytics.send("task.edited")
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

        // Capture index before delete for selection logic
        let listBeforeDelete: [TaskItem] = isSearchActive ? searchResults : store.tasks(for: key)
        let idx = listBeforeDelete.firstIndex(where: { $0.id == id })

        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == id }) {
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted '\(task.text)'", selectionToRestore: id))
        }

        store.deleteTask(dayKey: key, taskID: id)
        searchSessionPinnedIDs.remove(id)
        Analytics.send("task.deleted")

        if isSearchActive {
            let resultsAfter = searchResults
            if let idx, !resultsAfter.isEmpty {
                selection = resultsAfter[min(idx, resultsAfter.count - 1)].id
                focusListToken += 1
            } else {
                selection = nil
                searchFocusToken += 1
            }
        } else {
            let tasksAfter = store.tasks(for: key)
            if let idx, !tasksAfter.isEmpty {
                selection = tasksAfter[min(idx, tasksAfter.count - 1)].id
            } else {
                selection = tasksAfter.first?.id
            }
            if isToday { focusToken += 1 } else { focusListToken += 1 }
        }
    }

    func deleteTask(taskID: UUID) {
        let key = selectedKey
        if let bucket = store.days[key],
           let task = bucket.tasks.first(where: { $0.id == taskID }) {
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted '\(task.text)'", selectionToRestore: selection))
        }
        store.deleteTask(dayKey: key, taskID: taskID)
        searchSessionPinnedIDs.remove(taskID)
        Analytics.send("task.deleted")
    }

    func moveSelectedTask(direction: Int) -> Bool {
        guard isToday, !isEditing, !isSearchActive,
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
        guard isToday, !isEditing, !isSearchActive else { return }
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
        Analytics.send(isCompletedCollapsed ? "completedSection.collapsed" : "completedSection.expanded")
    }

    func focusList() {
        selection = (isSearchActive ? searchResults : tasks).first?.id
        focusListToken += 1
    }

    func focusInput() {
        if isToday { focusToken += 1 }
    }

    func handleReset() {
        if isEditing { cancelEdit() }
        if isSearchActive { closeSearch() }
        if isLaterOpen { closeLater() }
        selectedDate = Date()
        selection = nil
        focusToken += 1
    }

    func handleDateChange() {
        if isEditing { cancelEdit() }
        if isSearchActive { closeSearch() }
        if isLaterOpen { closeLater() }
        selection = nil
        if isToday { focusToken += 1 } else { focusList() }
    }

    func handleAppear() {
        if isEditing { cancelEdit() }
        if isSearchActive { closeSearch() }
        if isLaterOpen { closeLater() }
        if isToday { focusToken += 1 } else { focusList() }
    }

    func handleUpArrow() -> Bool {
        if isSearchActive {
            let firstID = searchResults.first?.id
            if selection == nil || selection == firstID {
                selection = nil
                searchFocusToken += 1
                return true
            }
            return false
        }
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

    // MARK: - Search

    func toggleCheatSheet() {
        isCheatSheetOpen.toggle()
        if isCheatSheetOpen { Analytics.send("shortcuts.cheatSheetOpened") }
        if isLaterOpen { closeLater() }
    }
    func closeCheatSheet() { isCheatSheetOpen = false }

    func openSearch() {
        guard !isSearchActive, !isLaterOpen else { return }
        if isEditing { cancelEdit() }
        isSearchActive = true
        searchQuery = ""
        searchSessionPinnedIDs = []
        selection = nil
        searchFocusToken += 1
    }

    func closeSearch() {
        guard isSearchActive else { return }
        isSearchActive = false
        searchQuery = ""
        searchSessionPinnedIDs = []
        // Keep current selection if valid, otherwise clear
        if let sel = selection, tasks.contains(where: { $0.id == sel }) {
            focusListToken += 1
        } else {
            selection = nil
            if isToday { focusToken += 1 } else { focusList() }
        }
    }

    func handleSearchEsc() {
        if !searchQuery.isEmpty {
            searchQuery = ""
        } else {
            closeSearch()
        }
    }

    private func pinTaskInSearch(_ id: UUID) {
        if isSearchActive {
            searchSessionPinnedIDs.insert(id)
        }
    }

    func focusSearchField() {
        searchFocusToken += 1
    }

    // MARK: - Later

    func openLater() {
        if isCheatSheetOpen { isCheatSheetOpen = false }
        if isSearchActive { closeSearch() }
        if isEditing { cancelEdit() }
        isLaterOpen = true
        laterSelection = nil
        Analytics.send("later.viewed")
    }

    func closeLater() {
        if isLaterSearchActive { closeLaterSearch() }
        if isLaterEditing { cancelLaterEdit() }
        isLaterOpen = false
        laterSelection = nil
        if isToday { focusToken += 1 } else { focusList() }
    }

    func toggleLater() {
        if isLaterOpen { closeLater() } else { openLater() }
    }

    func moveTaskToLater(taskID: UUID) {
        store.moveTaskToLater(dayKey: selectedKey, taskID: taskID)
        Analytics.send("task.movedToLater")
    }

    @discardableResult
    func moveSelectedToLater() -> Bool {
        guard isToday, let id = selection, !isCompletedHeaderSelected else { return false }
        moveTaskToLater(taskID: id)
        return true
    }

    @discardableResult
    func moveSelectedLaterToToday() -> Bool {
        guard let id = laterSelection else { return false }
        moveLaterToToday(taskID: id)
        return true
    }

    func moveSelectedLaterToToday(taskID: UUID) {
        moveLaterToToday(taskID: taskID)
    }

    func completeLaterTask(taskID: UUID) {
        moveLaterToToday(taskID: taskID)
        let key = store.todayKey
        store.toggleDone(dayKey: key, taskID: taskID)
        Analytics.send("task.completedFromLater")
    }

    private func moveLaterToToday(taskID: UUID) {
        let tasks = laterTasks
        let idx = tasks.firstIndex(where: { $0.id == taskID })
        store.moveTaskToToday(laterTaskID: taskID)
        Analytics.send("task.movedToToday")

        let remaining = laterTasks
        if let idx, !remaining.isEmpty {
            laterSelection = remaining[min(idx, remaining.count - 1)].id
        } else {
            laterSelection = remaining.first?.id
        }
    }

    func deleteLaterSelected() {
        guard let id = laterSelection else { return }
        let tasks = laterTasks
        let idx = tasks.firstIndex(where: { $0.id == id })
        store.deleteLaterTask(taskID: id)

        let remaining = laterTasks
        if let idx, !remaining.isEmpty {
            laterSelection = remaining[min(idx, remaining.count - 1)].id
        } else {
            laterSelection = remaining.first?.id
        }
    }

    func deleteLaterTask(taskID: UUID) {
        store.deleteLaterTask(taskID: taskID)
    }

    func startLaterEditing(taskID: UUID) {
        guard let task = laterTasks.first(where: { $0.id == taskID }) else { return }
        laterEditingTaskID = taskID
        laterEditText = task.text
    }

    func startLaterEditingSelected() -> Bool {
        guard let id = laterSelection else { return false }
        startLaterEditing(taskID: id)
        return true
    }

    func commitLaterEdit() {
        guard let taskID = laterEditingTaskID else { return }
        store.updateLaterTaskText(taskID: taskID, text: laterEditText)
        laterEditingTaskID = nil
        laterEditText = ""
        laterFocusListToken += 1
    }

    func cancelLaterEdit() {
        laterEditingTaskID = nil
        laterEditText = ""
        laterFocusListToken += 1
    }

    func laterFocusList() {
        laterSelection = (isLaterSearchActive ? laterSearchResults : laterTasks).first?.id
        laterFocusListToken += 1
    }

    func moveLaterSelectedTask(direction: Int) -> Bool {
        guard !isLaterEditing, !isLaterSearchActive,
              let id = laterSelection else { return false }
        store.moveLaterTask(taskID: id, direction: direction)
        return true
    }

    func reorderLaterTasks(fromOffsets: IndexSet, toOffset: Int) {
        guard !isLaterEditing, !isLaterSearchActive else { return }
        store.reorderLaterTasks(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func beginLaterDrag(taskID: UUID) {
        laterDragSnapshot = store.laterTasks
        laterDraggingTaskID = taskID
    }

    func endLaterDrag() {
        guard laterDraggingTaskID != nil else { return }
        if let id = laterDraggingTaskID {
            laterSelection = id
        }
        laterDraggingTaskID = nil
        laterDragSnapshot = nil
    }

    func openLaterSearch() {
        guard !isLaterSearchActive else { return }
        if isLaterEditing { cancelLaterEdit() }
        isLaterSearchActive = true
        laterSearchQuery = ""
        laterSelection = nil
        laterSearchFocusToken += 1
    }

    func closeLaterSearch() {
        guard isLaterSearchActive else { return }
        isLaterSearchActive = false
        laterSearchQuery = ""
        if let sel = laterSelection, laterTasks.contains(where: { $0.id == sel }) {
            laterFocusListToken += 1
        } else {
            laterSelection = nil
            laterFocusListToken += 1
        }
    }

    func handleLaterSearchEsc() {
        if !laterSearchQuery.isEmpty {
            laterSearchQuery = ""
        } else {
            closeLaterSearch()
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
        Analytics.send("undo.triggered")
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
