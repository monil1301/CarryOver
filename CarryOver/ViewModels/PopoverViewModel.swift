//
//  PopoverViewModel.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import SwiftUI
internal import Combine

/// Row entries consumed by the List. A "parent" is a top-level task; a "subtask" references its
/// parent by ID so the renderer can look up context (nesting, left border) without storing
/// redundant state on the subtask itself.
enum ListRow: Identifiable, Equatable {
    case parent(TaskItem)
    case subtask(parentID: UUID, Subtask)

    var id: UUID {
        switch self {
        case .parent(let t): return t.id
        case .subtask(_, let s): return s.id
        }
    }
}

/// Entry produced by paste parsing. Indented lines become `.sub`, non-indented become `.top`.
enum PastedEntry: Equatable {
    case top(String)
    case sub(String)
}

/// Autocomplete hint surfaced under the input while the user is composing `<text> :in <parent>`.
/// `parentMatch` is nil when the query doesn't match any top-level task yet.
struct SubSyntaxHint: Equatable {
    let parentMatch: TaskItem?
    let rawQuery: String
}

struct UndoAction: Equatable {
    let dayKey: String?
    let snapshot: DayBucket?
    let daysSnapshot: [String: DayBucket]?
    let laterSnapshot: [TaskItem]?
    let label: String
    let selectionToRestore: UUID?
    let laterSelectionToRestore: UUID?

    init(
        dayKey: String? = nil,
        snapshot: DayBucket? = nil,
        daysSnapshot: [String: DayBucket]? = nil,
        laterSnapshot: [TaskItem]? = nil,
        label: String,
        selectionToRestore: UUID? = nil,
        laterSelectionToRestore: UUID? = nil
    ) {
        self.dayKey = dayKey
        self.snapshot = snapshot
        self.daysSnapshot = daysSnapshot
        self.laterSnapshot = laterSnapshot
        self.label = label
        self.selectionToRestore = selectionToRestore
        self.laterSelectionToRestore = laterSelectionToRestore
    }
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
    var showDatePicker: Bool = false {
        didSet {
            if !showDatePicker && oldValue {
                if isToday { focusToken += 1 } else { focusList() }
            }
            sendChange()
        }
    }
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
    var isToday: Bool { selectedKey == store.todayKey }
    var isYesterday: Bool { selectedKey == store.yesterdayKey }

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

    /// Flattened row order for the undone section: parent first, then its subtasks (skipped
    /// when the parent is collapsed).
    var undoneRows: [ListRow] {
        undoneTasks.flatMap { t in
            var rows: [ListRow] = [.parent(t)]
            if !collapsedParentIDs.contains(t.id) {
                rows.append(contentsOf: t.subtasks.map { .subtask(parentID: t.id, $0) })
            }
            return rows
        }
    }

    /// Flattened row order for the Completed section: done parents + their subtasks (skipped
    /// when the parent is collapsed).
    var doneRows: [ListRow] {
        doneTasks.flatMap { t in
            var rows: [ListRow] = [.parent(t)]
            if !collapsedParentIDs.contains(t.id) {
                rows.append(contentsOf: t.subtasks.map { .subtask(parentID: t.id, $0) })
            }
            return rows
        }
    }

    /// Flattened row order in raw `tasks` array order — used by past-day rendering so a
    /// done-state flip doesn't shuffle rows across an undone/done boundary.
    var allRows: [ListRow] {
        tasks.flatMap { t in
            var rows: [ListRow] = [.parent(t)]
            if !collapsedParentIDs.contains(t.id) {
                rows.append(contentsOf: t.subtasks.map { .subtask(parentID: t.id, $0) })
            }
            return rows
        }
    }

    /// Locate a UUID within the current day's bucket. A single UUID can be either a top-level
    /// task or a subtask; selection uses the same id space, so callers branch on the result.
    enum Located: Equatable {
        case task(index: Int)
        case subtask(parentIndex: Int, subtaskIndex: Int)
        case notFound
    }

    func locate(_ id: UUID, in dayKey: String? = nil) -> Located {
        let key = dayKey ?? selectedKey
        guard let bucket = store.days[key] else { return .notFound }
        if let i = bucket.tasks.firstIndex(where: { $0.id == id }) {
            return .task(index: i)
        }
        for (pi, p) in bucket.tasks.enumerated() {
            if let si = p.subtasks.firstIndex(where: { $0.id == id }) {
                return .subtask(parentIndex: pi, subtaskIndex: si)
            }
        }
        return .notFound
    }

    func parentIDOfSubtask(_ id: UUID, in dayKey: String? = nil) -> UUID? {
        let key = dayKey ?? selectedKey
        guard let bucket = store.days[key] else { return nil }
        for p in bucket.tasks {
            if p.subtasks.contains(where: { $0.id == id }) { return p.id }
        }
        return nil
    }

    /// Tracks the most recently added top-level task id so `:in <text>` has a fallback anchor
    /// when nothing is selected.
    private var lastAddedTopLevelID: UUID?

    /// Parents whose subtask rows are hidden from the flattened list. Ephemeral — cleared on
    /// relaunch, matching the lightweight feel of the utility.
    private var collapsedParentIDs: Set<UUID> = [] {
        didSet { sendChange() }
    }

    func isParentCollapsed(_ id: UUID) -> Bool {
        collapsedParentIDs.contains(id)
    }

    /// Click handler on the progress pill. Toggles collapse and, when hiding subtasks, pulls
    /// selection back to the parent so it never ends up pointing into a hidden row.
    func toggleParentCollapse(_ parentID: UUID) {
        guard let bucket = store.days[selectedKey],
              let task = bucket.tasks.first(where: { $0.id == parentID }),
              !task.subtasks.isEmpty else { return }
        if collapsedParentIDs.contains(parentID) {
            collapsedParentIDs.remove(parentID)
        } else {
            if let sel = selection, task.subtasks.contains(where: { $0.id == sel }) {
                selection = parentID
            }
            collapsedParentIDs.insert(parentID)
        }
    }

    /// Left arrow: collapse the selected parent when it has subtasks and is currently expanded.
    @discardableResult
    func collapseSelectedParent() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        guard case .task = locate(id) else { return false }
        guard let task = store.days[selectedKey]?.tasks.first(where: { $0.id == id }),
              !task.subtasks.isEmpty,
              !collapsedParentIDs.contains(id) else { return false }
        collapsedParentIDs.insert(id)
        return true
    }

    /// Right arrow: expand the selected parent when it has subtasks and is currently collapsed.
    @discardableResult
    func expandSelectedParent() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        guard case .task = locate(id) else { return false }
        guard let task = store.days[selectedKey]?.tasks.first(where: { $0.id == id }),
              !task.subtasks.isEmpty,
              collapsedParentIDs.contains(id) else { return false }
        collapsedParentIDs.remove(id)
        return true
    }

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
        return store.effectiveDayKey(for: task.createdAt) != store.todayKey
    }

    var laterTasks: [TaskItem] { store.laterTasks }
    var laterCount: Int { store.laterTasks.count }
    var hasLaterTasks: Bool { !store.laterTasks.isEmpty }
    var isLaterEditing: Bool { laterEditingTaskID != nil }

    /// Flattened row order for the Later view. Parent first, then subtasks (skipped when the
    /// parent is collapsed). Respects the active search filter so a searched parent still
    /// shows its subtasks below it.
    var laterRows: [ListRow] {
        let tasks = isLaterSearchActive ? laterSearchResults : laterTasks
        return tasks.flatMap { t in
            var rows: [ListRow] = [.parent(t)]
            if !collapsedParentIDs.contains(t.id) {
                rows.append(contentsOf: t.subtasks.map { .subtask(parentID: t.id, $0) })
            }
            return rows
        }
    }

    /// Selection-aware lookup in the Later bucket.
    func laterLocate(_ id: UUID) -> Located {
        if let i = store.laterTasks.firstIndex(where: { $0.id == id }) {
            return .task(index: i)
        }
        for (pi, p) in store.laterTasks.enumerated() {
            if let si = p.subtasks.firstIndex(where: { $0.id == id }) {
                return .subtask(parentIndex: pi, subtaskIndex: si)
            }
        }
        return .notFound
    }

    func isLaterParentCollapsed(_ id: UUID) -> Bool { collapsedParentIDs.contains(id) }

    func toggleLaterParentCollapse(_ parentID: UUID) {
        guard let task = store.laterTasks.first(where: { $0.id == parentID }),
              !task.subtasks.isEmpty else { return }
        if collapsedParentIDs.contains(parentID) {
            collapsedParentIDs.remove(parentID)
        } else {
            if let sel = laterSelection, task.subtasks.contains(where: { $0.id == sel }) {
                laterSelection = parentID
            }
            collapsedParentIDs.insert(parentID)
        }
    }

    @discardableResult
    func collapseSelectedLaterParent() -> Bool {
        guard let id = laterSelection else { return false }
        guard case .task = laterLocate(id) else { return false }
        guard let task = store.laterTasks.first(where: { $0.id == id }),
              !task.subtasks.isEmpty,
              !collapsedParentIDs.contains(id) else { return false }
        collapsedParentIDs.insert(id)
        return true
    }

    @discardableResult
    func expandSelectedLaterParent() -> Bool {
        guard let id = laterSelection else { return false }
        guard case .task = laterLocate(id) else { return false }
        guard let task = store.laterTasks.first(where: { $0.id == id }),
              !task.subtasks.isEmpty,
              collapsedParentIDs.contains(id) else { return false }
        collapsedParentIDs.remove(id)
        return true
    }

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
        self.selectedDate = store.effectiveNow()
        storeCancellable = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func addTask() {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // `<subtask> :in <parent>` power-user syntax: split on the separator and match the
        // parent by text against today's top-level tasks. If no parent matches, fall through
        // to a normal top-level task with the literal input.
        if let (subText, parentQuery) = parseSubSyntax(trimmed),
           let parent = findParentMatch(parentQuery, in: store.tasks(for: store.todayKey)) {
            let key = store.todayKey
            let snapshot = store.days[key, default: DayBucket()]
            if store.addSubtask(dayKey: key, parentID: parent.id, text: subText) != nil {
                registerUndo(UndoAction(
                    dayKey: key,
                    snapshot: snapshot,
                    label: "Added '\(subText)' under '\(parent.text)'",
                    selectionToRestore: selection
                ))
                Analytics.send("subtask.added", with: ["method": "syntax"])
                newText = ""
                focusToken += 1
                return
            }
        }

        if let newID = store.addTaskToday(trimmed) {
            lastAddedTopLevelID = newID
        }
        newText = ""
        focusToken += 1
        Analytics.send("task.added")
    }

    /// Splits `<subtask> :in <parent>` (case-insensitive separator, whitespace-delimited)
    /// into its two halves. Returns nil when the input doesn't contain the separator or when
    /// either side is empty.
    private func parseSubSyntax(_ trimmed: String) -> (subtask: String, parentQuery: String)? {
        guard let range = trimmed.range(of: " :in ", options: .caseInsensitive) else { return nil }
        let sub = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty, !parent.isEmpty else { return nil }
        return (String(sub), String(parent))
    }

    /// The id of the top-level task currently matched by `:in` syntax — used by the list to
    /// highlight the prospective parent as the user types.
    var subSyntaxHintedParentID: UUID? { subSyntaxHint?.parentMatch?.id }

    /// Live hint derived from `newText`. Non-nil whenever the input contains ` :in` (with a
    /// leading space), which signals the user is mid-composition. Consumed by the UI to render
    /// the autocomplete row below the input.
    var subSyntaxHint: SubSyntaxHint? {
        let raw = newText
        guard let subRange = raw.range(of: " :in", options: .caseInsensitive) else { return nil }
        let afterSub = raw[subRange.upperBound...]
        let query: String
        if afterSub.isEmpty {
            query = ""
        } else if let first = afterSub.first, first == " " || first == "\t" {
            query = afterSub.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // `:include`, `:info`, or similar — not subtask syntax.
            return nil
        }
        let match = query.isEmpty ? nil : findParentMatch(query, in: store.tasks(for: store.todayKey))
        return SubSyntaxHint(parentMatch: match, rawQuery: query)
    }

    /// Tab-to-complete handler. Replaces the partial parent query in `newText` with the full
    /// matched parent text. Returns true when a completion was applied so the bridge can consume
    /// the Tab event; false falls back to the default "move focus to list" behavior.
    @discardableResult
    func completeSubSyntax() -> Bool {
        guard let hint = subSyntaxHint, let parent = hint.parentMatch else { return false }
        guard let range = newText.range(of: " :in ", options: .caseInsensitive) else { return false }
        let prefix = String(newText[..<range.upperBound])
        newText = prefix + parent.text
        return true
    }

    /// Finds the best top-level task matching `query` in the given bucket. Exact match beats
    /// prefix match beats substring match; within the same tier, first in bucket order wins.
    /// Case-insensitive.
    private func findParentMatch(_ query: String, in tasks: [TaskItem]) -> TaskItem? {
        let q = query.lowercased()
        enum Quality: Int { case substring = 1, prefix = 2, exact = 3 }
        var best: (task: TaskItem, quality: Quality)?
        for task in tasks {
            let t = task.text.lowercased()
            let quality: Quality?
            if t == q { quality = .exact }
            else if t.hasPrefix(q) { quality = .prefix }
            else if t.contains(q) { quality = .substring }
            else { quality = nil }
            if let qty = quality {
                if best == nil || qty.rawValue > best!.quality.rawValue {
                    best = (task, qty)
                }
                if qty == .exact { break }
            }
        }
        return best?.task
    }

    func addTasksFromPaste(_ entries: [PastedEntry]) {
        guard !entries.isEmpty else { return }
        let key = store.todayKey
        let snapshot = store.days[key, default: DayBucket()]

        var currentParentID: UUID?
        var subtaskCount = 0
        for entry in entries {
            switch entry {
            case .top(let text):
                if let id = store.addTaskToday(text) {
                    currentParentID = id
                    lastAddedTopLevelID = id
                }
            case .sub(let text):
                if let parentID = currentParentID {
                    if store.addSubtask(dayKey: key, parentID: parentID, text: text) != nil {
                        subtaskCount += 1
                    }
                } else if let id = store.addTaskToday(text) {
                    // Indented line with no preceding top-level entry degrades to top-level.
                    currentParentID = id
                    lastAddedTopLevelID = id
                }
            }
        }

        let count = store.tasks(for: key).count - snapshot.tasks.count + subtaskCount
        if count > 0 {
            registerUndo(UndoAction(
                dayKey: key,
                snapshot: snapshot,
                label: count == 1 ? "1 task added" : "\(count) tasks added",
                selectionToRestore: selection
            ))
        }

        newText = ""
        focusToken += 1
        Analytics.send("pasteAsTasks.used")
        if subtaskCount > 0 {
            for _ in 0..<subtaskCount {
                Analytics.send("subtask.added", with: ["method": "paste"])
            }
        }
    }

    static func parsePastedTasks(_ text: String) -> [PastedEntry] {
        let markerPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*•+]|\[[ xX]\]|\d+[.)]) +(.*)"#)
        let lines = text.components(separatedBy: .newlines)
        var results: [PastedEntry] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let isIndented = (line.first == " " || line.first == "\t")
            let content: String
            let range = NSRange(line.startIndex..., in: line)
            if let match = markerPattern.firstMatch(in: line, range: range) {
                content = String(line[Range(match.range(at: 3), in: line)!])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                content = trimmed
            }
            guard !content.isEmpty else { continue }

            if isIndented, !results.isEmpty {
                results.append(.sub(content))
            } else {
                results.append(.top(content))
            }
        }

        return results
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
        guard let bucket = store.days[key] else { return }

        switch locate(taskID, in: key) {
        case .task(let i):
            let task = bucket.tasks[i]
            let label = task.isDone ? "Unmarked '\(task.text)'" : "Completed '\(task.text)'"
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: label, selectionToRestore: selection))
            if !task.isDone { Analytics.send("task.completed") }
            store.toggleTaskDoneCascading(dayKey: key, taskID: taskID, reorder: isToday)
            pinTaskInSearch(taskID)

        case .subtask(let pi, let si):
            let parent = bucket.tasks[pi]
            let sub = parent.subtasks[si]
            let label = sub.isDone ? "Unmarked subtask" : "Completed subtask"
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: label, selectionToRestore: selection))
            let wasDone = sub.isDone
            let allDone = store.toggleSubtaskDone(dayKey: key, parentID: parent.id, subtaskID: taskID, reorder: isToday)
            if !wasDone { Analytics.send("subtask.completed") }
            // Auto-complete parent if the setting is on and the subtask flip made all-done true.
            if !wasDone, allDone,
               SubtaskPreferences.currentAutoCompleteParent(),
               let refreshed = store.days[key]?.tasks.first(where: { $0.id == parent.id }),
               !refreshed.isDone {
                store.toggleTaskDoneCascading(dayKey: key, taskID: parent.id, reorder: isToday)
                Analytics.send("parent.autoCompleted")
            }
            // Auto-uncomplete parent if the setting is on and a subtask was just unmarked
            // under a parent that is currently done — keeps parent state mirrored to subtasks.
            // Skip the row reorder on past days so the parent doesn't visually jump from the
            // done group to the undone group.
            if wasDone,
               SubtaskPreferences.currentAutoCompleteParent(),
               let refreshed = store.days[key]?.tasks.first(where: { $0.id == parent.id }),
               refreshed.isDone {
                store.toggleTaskDoneCascading(dayKey: key, taskID: parent.id, reorder: isToday)
                Analytics.send("parent.autoUncompleted")
            }

        case .notFound:
            return
        }
    }

    func toggleSelectedDone() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        toggleDone(taskID: id)
        return true
    }

    func startEditing(taskID: UUID) {
        let key = selectedKey
        switch locate(taskID, in: key) {
        case .task(let i):
            guard let bucket = store.days[key] else { return }
            editingTaskID = taskID
            editText = bucket.tasks[i].text
        case .subtask(let pi, let si):
            guard let bucket = store.days[key] else { return }
            editingTaskID = taskID
            editText = bucket.tasks[pi].subtasks[si].text
        case .notFound:
            return
        }
    }

    func startEditingSelected() -> Bool {
        guard let id = selection, !isCompletedHeaderSelected else { return false }
        startEditing(taskID: id)
        return true
    }

    func commitEdit() {
        guard let taskID = editingTaskID else { return }
        let key = selectedKey

        switch locate(taskID, in: key) {
        case .task:
            if let bucket = store.days[key],
               let task = bucket.tasks.first(where: { $0.id == taskID }) {
                registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Edited '\(task.text)'", selectionToRestore: taskID))
            }
            store.updateTaskText(dayKey: key, taskID: taskID, text: editText)
            pinTaskInSearch(taskID)
            Analytics.send("task.edited")

        case .subtask(let pi, _):
            guard let bucket = store.days[key] else {
                editingTaskID = nil; editText = ""; focusListToken += 1
                return
            }
            let parentID = bucket.tasks[pi].id
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Edited subtask", selectionToRestore: taskID))
            store.updateSubtaskText(dayKey: key, parentID: parentID, subtaskID: taskID, text: editText)

        case .notFound:
            break
        }

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

        switch locate(id, in: key) {
        case .subtask(let pi, let si):
            guard let bucket = store.days[key] else { return }
            let parentID = bucket.tasks[pi].id
            let siblings = bucket.tasks[pi].subtasks
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted subtask", selectionToRestore: id))
            store.deleteSubtask(dayKey: key, parentID: parentID, subtaskID: id)
            Analytics.send("subtask.deleted")

            // Prefer next sibling, then previous, else fall back to the parent.
            let nextID: UUID? = {
                if si + 1 < siblings.count { return siblings[si + 1].id }
                if si - 1 >= 0 { return siblings[si - 1].id }
                return parentID
            }()
            selection = nextID
            focusListToken += 1
            return

        case .task, .notFound:
            break
        }

        // Top-level delete (original behavior).
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
        switch locate(taskID, in: key) {
        case .subtask(let pi, _):
            guard let bucket = store.days[key] else { return }
            let parentID = bucket.tasks[pi].id
            registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted subtask", selectionToRestore: selection))
            store.deleteSubtask(dayKey: key, parentID: parentID, subtaskID: taskID)
            Analytics.send("subtask.deleted")

        case .task:
            if let bucket = store.days[key],
               let task = bucket.tasks.first(where: { $0.id == taskID }) {
                registerUndo(UndoAction(dayKey: key, snapshot: bucket, label: "Deleted '\(task.text)'", selectionToRestore: selection))
            }
            store.deleteTask(dayKey: key, taskID: taskID)
            searchSessionPinnedIDs.remove(taskID)
            Analytics.send("task.deleted")

        case .notFound:
            break
        }
    }

    func moveSelectedTask(direction: Int) -> Bool {
        guard isToday, !isEditing, !isSearchActive,
              let id = selection, !isCompletedHeaderSelected else { return false }

        let key = selectedKey
        switch locate(id, in: key) {
        case .subtask(let pi, _):
            guard let bucket = store.days[key] else { return false }
            let parentID = bucket.tasks[pi].id
            let snapshot = bucket
            store.moveSubtask(dayKey: key, parentID: parentID, subtaskID: id, direction: direction)
            if let newBucket = store.days[key],
               newBucket.tasks[pi].subtasks.map(\.id) != snapshot.tasks[pi].subtasks.map(\.id) {
                registerUndo(UndoAction(dayKey: key, snapshot: snapshot, label: "Moved subtask", selectionToRestore: id))
            }
            return true

        case .task:
            guard let task = undoneTasks.first(where: { $0.id == id }), !task.isDone else { return false }
            let snapshot = store.days[key, default: DayBucket()]
            store.moveTask(dayKey: key, taskID: id, direction: direction)
            let newTasks = store.tasks(for: key)
            if newTasks.map(\.id) != snapshot.tasks.map(\.id) {
                registerUndo(UndoAction(dayKey: key, snapshot: snapshot, label: "Moved '\(task.text)'", selectionToRestore: id))
            }
            return true

        case .notFound:
            return false
        }
    }

    // MARK: - Subtask indent / unindent / add

    /// Tab key handler. Indents the selected top-level task as a subtask of the task above it.
    /// Returns true if the bridge should consume the Tab event.
    @discardableResult
    func indentSelectedTask() -> Bool {
        guard isToday, !isEditing, !isSearchActive,
              let id = selection, !isCompletedHeaderSelected else { return false }
        let key = selectedKey
        guard case .task(let i) = locate(id, in: key), i > 0 else { return false }
        guard let bucket = store.days[key] else { return false }
        // Subtask depth is 1: do not indent a task that already owns subtasks.
        guard bucket.tasks[i].subtasks.isEmpty else { return false }

        let snapshot = bucket
        if store.indentTaskAsSubtask(dayKey: key, taskID: id) != nil {
            registerUndo(UndoAction(
                dayKey: key,
                snapshot: snapshot,
                label: "Moved to subtask",
                selectionToRestore: id
            ))
            Analytics.send("subtask.added", with: ["method": "tab"])
            focusListToken += 1
            return true
        }
        return false
    }

    /// Shift+Tab handler. Promotes the selected subtask to a top-level task immediately after
    /// its former parent's remaining subtasks. Returns true if the bridge should consume.
    @discardableResult
    func unindentSelectedSubtask() -> Bool {
        guard isToday, !isEditing, !isSearchActive,
              let id = selection, !isCompletedHeaderSelected else { return false }
        let key = selectedKey
        guard case .subtask(let pi, _) = locate(id, in: key) else { return false }
        guard let bucket = store.days[key] else { return false }
        let parentID = bucket.tasks[pi].id
        let snapshot = bucket
        store.unindentSubtaskToTask(dayKey: key, parentID: parentID, subtaskID: id)
        registerUndo(UndoAction(
            dayKey: key,
            snapshot: snapshot,
            label: "Unindented subtask",
            selectionToRestore: id
        ))
        focusListToken += 1
        return true
    }

    /// Right-click "Add Subtask" menu action. Appends an empty subtask and opens inline edit.
    func addSubtaskFromContextMenu(parentID: UUID) {
        let key = selectedKey
        guard let snapshot = store.days[key] else { return }
        guard let newID = store.insertEmptySubtask(dayKey: key, parentID: parentID) else { return }
        registerUndo(UndoAction(
            dayKey: key,
            snapshot: snapshot,
            label: "Added subtask",
            selectionToRestore: selection
        ))
        Analytics.send("subtask.added", with: ["method": "rightclick"])
        selection = newID
        startEditing(taskID: newID)
    }

    // MARK: -

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

    func handleSlashKey() {
        guard isToday, !isLaterOpen, !isCheatSheetOpen, !showDatePicker, !isSearchActive else { return }
        selection = nil
        focusToken += 1
    }

    func handleReset() {
        if isEditing { cancelEdit() }
        if isSearchActive { closeSearch() }
        if isLaterOpen { closeLater() }
        selectedDate = store.effectiveNow()
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
        laterFocusListToken += 1
        isLaterOpen = true
        laterSelection = laterTasks.first?.id
        Analytics.send("later.viewed")
    }

    func closeLater() {
        if isLaterSearchActive { closeLaterSearch() }
        if isLaterEditing { cancelLaterEdit() }
        isLaterOpen = false
        laterSelection = nil
        // Reset so the recreated TaskListView's ListFocusBridge doesn't steal focus
        focusListToken = 0
        // Defer focus restoration to the next tick — if openLater() is called before
        // this fires (rapid Cmd+L after Esc), isLaterOpen will be true and we skip
        // the text field focus to avoid racing with LaterView's ListFocusBridge.
        if !showDatePicker {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isLaterOpen else { return }
                if self.isToday { self.focusToken += 1 } else { self.focusList() }
            }
        }
    }

    func toggleLater() {
        if isLaterOpen { closeLater() } else { openLater() }
    }

    func moveTaskToLater(taskID: UUID) {
        let key = selectedKey
        guard let bucket = store.days[key],
              let task = bucket.tasks.first(where: { $0.id == taskID }) else { return }
        let todaySnapshot = bucket
        let laterSnapshot = store.laterTasks

        store.moveTaskToLater(dayKey: key, taskID: taskID)
        Analytics.send("task.movedToLater")

        registerUndo(UndoAction(
            dayKey: key,
            snapshot: todaySnapshot,
            laterSnapshot: laterSnapshot,
            label: "Moved '\(task.text)' to Later",
            selectionToRestore: taskID
        ))
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
        moveSelectedLaterToToday(taskID: id)
        return true
    }

    func moveSelectedLaterToToday(taskID: UUID) {
        guard let task = store.laterTasks.first(where: { $0.id == taskID }) else { return }
        let todayKey = store.todayKey
        let todaySnapshot = store.days[todayKey, default: DayBucket()]
        let laterSnapshot = store.laterTasks
        let prevLaterSelection = laterSelection

        moveLaterToToday(taskID: taskID)

        registerUndo(UndoAction(
            dayKey: todayKey,
            snapshot: todaySnapshot,
            laterSnapshot: laterSnapshot,
            label: "Moved '\(task.text)' to Today",
            laterSelectionToRestore: prevLaterSelection
        ))
    }

    func completeLaterTask(taskID: UUID) {
        guard let task = store.laterTasks.first(where: { $0.id == taskID }) else { return }
        let todayKey = store.todayKey
        let todaySnapshot = store.days[todayKey, default: DayBucket()]
        let laterSnapshot = store.laterTasks
        let prevLaterSelection = laterSelection

        moveLaterToToday(taskID: taskID)
        store.toggleTaskDoneCascading(dayKey: todayKey, taskID: taskID)
        Analytics.send("task.completedFromLater")

        registerUndo(UndoAction(
            dayKey: todayKey,
            snapshot: todaySnapshot,
            laterSnapshot: laterSnapshot,
            label: "Completed '\(task.text)' from Later",
            laterSelectionToRestore: prevLaterSelection
        ))
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
        let laterSnapshot = store.laterTasks

        switch laterLocate(id) {
        case .subtask(let pi, let si):
            let parent = store.laterTasks[pi]
            let siblings = parent.subtasks
            store.deleteLaterSubtask(parentID: parent.id, subtaskID: id)
            Analytics.send("subtask.deleted")

            // Prefer next sibling, then previous, else the parent.
            let nextID: UUID? = {
                if si + 1 < siblings.count { return siblings[si + 1].id }
                if si - 1 >= 0 { return siblings[si - 1].id }
                return parent.id
            }()
            laterSelection = nextID

            registerUndo(UndoAction(
                laterSnapshot: laterSnapshot,
                label: "Deleted subtask",
                laterSelectionToRestore: id
            ))

        case .task:
            guard let task = store.laterTasks.first(where: { $0.id == id }) else { return }
            let idx = laterTasks.firstIndex(where: { $0.id == id })
            store.deleteLaterTask(taskID: id)

            let remaining = laterTasks
            if let idx, !remaining.isEmpty {
                laterSelection = remaining[min(idx, remaining.count - 1)].id
            } else {
                laterSelection = remaining.first?.id
            }

            registerUndo(UndoAction(
                laterSnapshot: laterSnapshot,
                label: "Deleted '\(task.text)'",
                laterSelectionToRestore: id
            ))

        case .notFound:
            return
        }
    }

    func deleteLaterTask(taskID: UUID) {
        let laterSnapshot = store.laterTasks
        switch laterLocate(taskID) {
        case .subtask(let pi, _):
            let parentID = store.laterTasks[pi].id
            store.deleteLaterSubtask(parentID: parentID, subtaskID: taskID)
            Analytics.send("subtask.deleted")
            registerUndo(UndoAction(
                laterSnapshot: laterSnapshot,
                label: "Deleted subtask",
                laterSelectionToRestore: laterSelection
            ))

        case .task:
            guard let task = store.laterTasks.first(where: { $0.id == taskID }) else { return }
            store.deleteLaterTask(taskID: taskID)
            registerUndo(UndoAction(
                laterSnapshot: laterSnapshot,
                label: "Deleted '\(task.text)'",
                laterSelectionToRestore: taskID
            ))

        case .notFound:
            break
        }
    }

    func startLaterEditing(taskID: UUID) {
        switch laterLocate(taskID) {
        case .task(let i):
            laterEditingTaskID = taskID
            laterEditText = store.laterTasks[i].text
        case .subtask(let pi, let si):
            laterEditingTaskID = taskID
            laterEditText = store.laterTasks[pi].subtasks[si].text
        case .notFound:
            return
        }
    }

    /// Directly toggles a Later subtask's done state. Used by the subtask row's checkbox tap so
    /// the action doesn't depend on `laterSelection` already pointing at the subtask.
    func toggleLaterSubtaskDone(subtaskID: UUID) {
        guard case .subtask(let pi, let si) = laterLocate(subtaskID) else { return }
        let parentID = store.laterTasks[pi].id
        let wasDone = store.laterTasks[pi].subtasks[si].isDone
        let snapshot = store.laterTasks
        store.toggleLaterSubtaskDone(parentID: parentID, subtaskID: subtaskID)
        registerUndo(UndoAction(
            laterSnapshot: snapshot,
            label: wasDone ? "Unmarked subtask" : "Completed subtask",
            laterSelectionToRestore: subtaskID
        ))
        if !wasDone { Analytics.send("subtask.completed") }
    }

    @discardableResult
    func completeSelectedLater() -> Bool {
        guard let id = laterSelection else { return false }
        switch laterLocate(id) {
        case .task:
            completeLaterTask(taskID: id)
            return true

        case .subtask(let pi, let si):
            let parentID = store.laterTasks[pi].id
            let wasDone = store.laterTasks[pi].subtasks[si].isDone
            let snapshot = store.laterTasks
            store.toggleLaterSubtaskDone(parentID: parentID, subtaskID: id)
            registerUndo(UndoAction(
                laterSnapshot: snapshot,
                label: wasDone ? "Unmarked subtask" : "Completed subtask",
                laterSelectionToRestore: id
            ))
            if !wasDone { Analytics.send("subtask.completed") }
            return true

        case .notFound:
            return false
        }
    }

    func startLaterEditingSelected() -> Bool {
        guard let id = laterSelection else { return false }
        startLaterEditing(taskID: id)
        return true
    }

    func commitLaterEdit() {
        guard let taskID = laterEditingTaskID else { return }

        switch laterLocate(taskID) {
        case .task:
            if let task = store.laterTasks.first(where: { $0.id == taskID }) {
                registerUndo(UndoAction(
                    laterSnapshot: store.laterTasks,
                    label: "Edited '\(task.text)'",
                    laterSelectionToRestore: taskID
                ))
            }
            store.updateLaterTaskText(taskID: taskID, text: laterEditText)

        case .subtask(let pi, _):
            let parentID = store.laterTasks[pi].id
            registerUndo(UndoAction(
                laterSnapshot: store.laterTasks,
                label: "Edited subtask",
                laterSelectionToRestore: taskID
            ))
            store.updateLaterSubtaskText(parentID: parentID, subtaskID: taskID, text: laterEditText)

        case .notFound:
            break
        }

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

        switch laterLocate(id) {
        case .subtask(let pi, _):
            let parentID = store.laterTasks[pi].id
            let snapshot = store.laterTasks
            store.moveLaterSubtask(parentID: parentID, subtaskID: id, direction: direction)
            if store.laterTasks[pi].subtasks.map(\.id) != snapshot[pi].subtasks.map(\.id) {
                registerUndo(UndoAction(
                    laterSnapshot: snapshot,
                    label: "Moved subtask",
                    laterSelectionToRestore: id
                ))
            }
            return true

        case .task:
            guard let task = store.laterTasks.first(where: { $0.id == id }) else { return false }
            let snapshot = store.laterTasks
            store.moveLaterTask(taskID: id, direction: direction)
            if store.laterTasks.map(\.id) != snapshot.map(\.id) {
                registerUndo(UndoAction(
                    laterSnapshot: snapshot,
                    label: "Moved '\(task.text)'",
                    laterSelectionToRestore: id
                ))
            }
            return true

        case .notFound:
            return false
        }
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
        if let snapshot = laterDragSnapshot, let id = laterDraggingTaskID {
            if store.laterTasks.map(\.id) != snapshot.map(\.id) {
                registerUndo(UndoAction(
                    laterSnapshot: snapshot,
                    label: "Reordered tasks",
                    laterSelectionToRestore: id
                ))
            }
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

    // MARK: - Rollover

    func handleRolloverResult(_ result: DailyStore.RolloverResult) {
        guard result.movedToLaterCount > 0,
              let daysSnap = result.daysSnapshotForUndo,
              let laterSnap = result.laterSnapshotForUndo else { return }

        Analytics.send("rollover.movedToLater", with: ["count": "\(result.movedToLaterCount)"])

        let label = result.movedToLaterCount == 1
            ? "Moved 1 task to Later"
            : "Moved \(result.movedToLaterCount) tasks to Later"

        registerUndo(UndoAction(
            daysSnapshot: daysSnap,
            laterSnapshot: laterSnap,
            label: label
        ))
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
        if let daysSnapshot = action.daysSnapshot {
            store.restoreDays(daysSnapshot)
        }
        if let key = action.dayKey, let snapshot = action.snapshot {
            store.restoreBucket(dayKey: key, bucket: snapshot)
        }
        if let laterSnapshot = action.laterSnapshot {
            store.restoreLater(tasks: laterSnapshot)
        }
        if let key = action.dayKey, selectedKey == key, let sel = action.selectionToRestore {
            selection = sel
        }
        if let laterSel = action.laterSelectionToRestore {
            laterSelection = laterSel
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
