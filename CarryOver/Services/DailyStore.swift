//
//  DailyStore.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import Foundation
import SwiftUI
internal import Combine

@MainActor
final class DailyStore: ObservableObject {
    struct RolloverResult {
        let carriedCount: Int
        let movedToLaterCount: Int
        let daysSnapshotForUndo: [String: DayBucket]?
        let laterSnapshotForUndo: [TaskItem]?
    }

    @Published private(set) var days: [String: DayBucket] = [:]
    @Published private(set) var laterTasks: [TaskItem] = []
    @Published var resetToken: Int = 0

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func effectiveNow() -> Date {
        let hour = RolloverPreferences.currentCutoffHour()
        return Calendar.current.date(byAdding: .hour, value: -hour, to: Date()) ?? Date()
    }

    func effectiveDayKey(for date: Date) -> String {
        let hour = RolloverPreferences.currentCutoffHour()
        let shifted = Calendar.current.date(byAdding: .hour, value: -hour, to: date) ?? date
        return df.string(from: shifted)
    }

    var todayKey: String { df.string(from: effectiveNow()) }

    var yesterdayKey: String {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: effectiveNow()) ?? effectiveNow()
        return df.string(from: prev)
    }

    private var appSupportDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("CarryOver", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var fileURL: URL { appSupportDir.appendingPathComponent("data.json") }
    private var laterFileURL: URL { appSupportDir.appendingPathComponent("later.json") }

    @discardableResult
    func load() -> RolloverResult {
        do {
            let data = try Data(contentsOf: fileURL)
            days = try JSONDecoder().decode([String: DayBucket].self, from: data)
        } catch {
            days = [:]
        }

        loadLater()
        return rolloverUnfinishedToToday()
    }

    private func loadLater() {
        do {
            let data = try Data(contentsOf: laterFileURL)
            laterTasks = try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            laterTasks = []
        }
    }

    func saveLater() {
        do {
            let data = try JSONEncoder().encode(laterTasks)
            try data.write(to: laterFileURL, options: [.atomic])
        } catch {
            // keep silent for now
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(days)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // keep silent for now
        }
    }

    func tasks(for dayKey: String) -> [TaskItem] {
        days[dayKey]?.tasks ?? []
    }

    @discardableResult
    func addTaskToday(_ text: String) -> UUID? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        let key = todayKey
        var bucket = days[key, default: DayBucket()]

        // Insert at the end of unfinished tasks (right before first done task)
        let insertIndex = bucket.tasks.firstIndex(where: { $0.isDone }) ?? bucket.tasks.count
        let new = TaskItem(text: t)
        bucket.tasks.insert(new, at: insertIndex)

        days[key] = bucket
        save()
        return new.id
    }

    func addTasksToday(_ texts: [String]) {
        let key = todayKey
        var bucket = days[key, default: DayBucket()]
        let insertIndex = bucket.tasks.firstIndex(where: { $0.isDone }) ?? bucket.tasks.count
        for (i, text) in texts.enumerated() {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            bucket.tasks.insert(TaskItem(text: t), at: insertIndex + i)
        }
        days[key] = bucket
        save()
    }

    func toggleDone(dayKey: String, taskID: UUID) {
        guard var bucket = days[dayKey],
              let i = bucket.tasks.firstIndex(where: { $0.id == taskID }) else { return }

        bucket.tasks[i].isDone.toggle()
        bucket.tasks[i].completedAt = bucket.tasks[i].isDone ? Date() : nil
        days[dayKey] = bucket

        normalizeOrder(dayKey: dayKey)
        save()
    }

    /// Core feature: unfinished tasks from older days move into today; done tasks stay on their day.
    /// Tasks older than the auto-move-to-Later threshold are routed to the Later bucket instead.
    @discardableResult
    func rolloverUnfinishedToToday() -> RolloverResult {
        let today = todayKey
        let threshold = RolloverPreferences.currentThreshold()
        let now = Date()
        let cal = Calendar.current

        let daysSnapshot = days
        let laterSnapshot = laterTasks

        var incoming: [TaskItem] = []
        var toLater: [TaskItem] = []

        for (dayKey, bucket) in days {
            guard dayKey < today else { continue } // works because yyyy-MM-dd
            let undone = bucket.tasks.filter { !$0.isDone }
            if !undone.isEmpty {
                if threshold > 0 {
                    for task in undone {
                        let age = cal.dateComponents([.day], from: task.createdAt, to: now).day ?? 0
                        if age >= threshold {
                            var copy = task
                            copy.isDone = false
                            copy.completedAt = nil
                            toLater.append(copy)
                        } else {
                            incoming.append(task)
                        }
                    }
                } else {
                    incoming.append(contentsOf: undone)
                }
                let doneOnly = bucket.tasks.filter { $0.isDone }
                days[dayKey]?.tasks = doneOnly
            }
        }

        if !incoming.isEmpty {
            days[today, default: DayBucket()].tasks = incoming + (days[today]?.tasks ?? [])
        }

        if !toLater.isEmpty {
            laterTasks.append(contentsOf: toLater)
            saveLater()
        }

        normalizeOrder(dayKey: today)
        save()

        return RolloverResult(
            carriedCount: incoming.count,
            movedToLaterCount: toLater.count,
            daysSnapshotForUndo: toLater.isEmpty ? nil : daysSnapshot,
            laterSnapshotForUndo: toLater.isEmpty ? nil : laterSnapshot
        )
    }

    func restoreDays(_ snapshot: [String: DayBucket]) {
        days = snapshot
        save()
    }
    
    func dayKey(for date: Date) -> String { df.string(from: date) }

    func date(fromKey key: String) -> Date? { df.date(from: key) }
    
    func note(for dayKey: String) -> String {
        days[dayKey]?.note ?? ""
    }

    func setNote(dayKey: String, text: String) {
        days[dayKey, default: DayBucket()].note = text
        save()
    }

    var availableDayKeysSortedDesc: [String] {
        days.keys.sorted(by: >)  // newest first
    }
    
    private func normalizeOrder(dayKey: String) {
        guard var bucket = days[dayKey] else { return }
        let undone = bucket.tasks.filter { !$0.isDone }
        let done = bucket.tasks.filter { $0.isDone }
        bucket.tasks = undone + done
        days[dayKey] = bucket
    }
    
    func updateTaskText(dayKey: String, taskID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var bucket = days[dayKey],
              let i = bucket.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        bucket.tasks[i].text = trimmed
        days[dayKey] = bucket
        save()
    }

    func deleteTask(dayKey: String, taskID: UUID) {
        guard var bucket = days[dayKey] else { return }
        bucket.tasks.removeAll { $0.id == taskID }
        days[dayKey] = bucket
        save()
    }

    func moveTask(dayKey: String, taskID: UUID, direction: Int) {
        guard var bucket = days[dayKey],
              let idx = bucket.tasks.firstIndex(where: { $0.id == taskID }),
              !bucket.tasks[idx].isDone else { return }

        let undoneCount = bucket.tasks.prefix(while: { !$0.isDone }).count
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < undoneCount else { return }

        bucket.tasks.swapAt(idx, newIdx)
        days[dayKey] = bucket
        save()
    }

    func reorderUndoneTasks(dayKey: String, fromOffsets: IndexSet, toOffset: Int) {
        guard var bucket = days[dayKey] else { return }
        var undone = bucket.tasks.filter { !$0.isDone }
        let done = bucket.tasks.filter { $0.isDone }
        undone.move(fromOffsets: fromOffsets, toOffset: toOffset)
        bucket.tasks = undone + done
        days[dayKey] = bucket
        save()
    }

    func restoreBucket(dayKey: String, bucket: DayBucket) {
        days[dayKey] = bucket
        save()
    }

    func restoreLater(tasks: [TaskItem]) {
        laterTasks = tasks
        saveLater()
    }

    // MARK: - Import

    func applyImport(payload: ExportPayload) -> MergeSummary {
        var summary = MergeSummary()

        for (dayKey, importedBucket) in payload.days {
            if var existing = days[dayKey] {
                summary.daysMerged += 1
                var byID = Dictionary(uniqueKeysWithValues: existing.tasks.map { ($0.id, $0) })
                for imported in importedBucket.tasks {
                    if var local = byID[imported.id] {
                        if !local.isDone && imported.isDone {
                            local.isDone = true
                            local.completedAt = imported.completedAt ?? Date()
                            summary.tasksUpdated += 1
                        }
                        local.subtasks = mergedSubtasks(local: local.subtasks, imported: imported.subtasks)
                        byID[imported.id] = local
                    } else {
                        byID[imported.id] = imported
                        summary.tasksAdded += 1
                    }
                }
                let originalOrder = existing.tasks.map(\.id)
                var merged: [TaskItem] = []
                merged.reserveCapacity(byID.count)
                var seen = Set<UUID>()
                for id in originalOrder {
                    if let t = byID[id] { merged.append(t); seen.insert(id) }
                }
                for imported in importedBucket.tasks where !seen.contains(imported.id) {
                    if let t = byID[imported.id] { merged.append(t); seen.insert(imported.id) }
                }
                existing.tasks = merged
                if existing.note.isEmpty && !importedBucket.note.isEmpty {
                    existing.note = importedBucket.note
                }
                days[dayKey] = existing
                normalizeOrder(dayKey: dayKey)
            } else {
                days[dayKey] = importedBucket
                summary.daysAdded += 1
                summary.tasksAdded += importedBucket.tasks.count
                normalizeOrder(dayKey: dayKey)
            }
        }

        var laterByID = Dictionary(uniqueKeysWithValues: laterTasks.map { ($0.id, $0) })
        var laterOrder = laterTasks.map(\.id)
        for imported in payload.later {
            if var local = laterByID[imported.id] {
                if !local.isDone && imported.isDone {
                    local.isDone = true
                    local.completedAt = imported.completedAt ?? Date()
                    laterByID[imported.id] = local
                    summary.laterUpdated += 1
                }
            } else {
                laterByID[imported.id] = imported
                laterOrder.append(imported.id)
                summary.laterAdded += 1
            }
        }
        laterTasks = laterOrder.compactMap { laterByID[$0] }

        save()
        saveLater()
        return summary
    }

    func exportPayloadData() throws -> Data {
        try ImportExportService.encode(days: days, later: laterTasks)
    }

    // MARK: - Subtasks

    /// Toggles a top-level task's done state, cascading the new state to all of its subtasks
    /// when marking done (stamping completedAt on any that weren't already done).
    /// Un-marking a parent leaves subtask states alone.
    func toggleTaskDoneCascading(dayKey: String, taskID: UUID, reorder: Bool = true) {
        guard var bucket = days[dayKey],
              let i = bucket.tasks.firstIndex(where: { $0.id == taskID }) else { return }

        let newDone = !bucket.tasks[i].isDone
        bucket.tasks[i].isDone = newDone
        bucket.tasks[i].completedAt = newDone ? Date() : nil

        if newDone {
            let now = Date()
            for s in bucket.tasks[i].subtasks.indices where !bucket.tasks[i].subtasks[s].isDone {
                bucket.tasks[i].subtasks[s].isDone = true
                bucket.tasks[i].subtasks[s].completedAt = now
            }
            normalizeSubtasksOrder(&bucket.tasks[i].subtasks)
        }

        days[dayKey] = bucket
        if reorder {
            normalizeOrder(dayKey: dayKey)
        }
        save()
    }

    @discardableResult
    func addSubtask(dayKey: String, parentID: UUID, text: String) -> UUID? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }) else { return nil }
        let new = Subtask(text: t)
        bucket.tasks[p].subtasks.append(new)
        normalizeSubtasksOrder(&bucket.tasks[p].subtasks)
        days[dayKey] = bucket
        save()
        return new.id
    }

    @discardableResult
    func insertEmptySubtask(dayKey: String, parentID: UUID) -> UUID? {
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }) else { return nil }
        let new = Subtask(text: "")
        // Insert after the last undone subtask so it appears at the end of the undone group.
        let insertIndex = bucket.tasks[p].subtasks.firstIndex(where: { $0.isDone }) ?? bucket.tasks[p].subtasks.count
        bucket.tasks[p].subtasks.insert(new, at: insertIndex)
        days[dayKey] = bucket
        save()
        return new.id
    }

    func updateSubtaskText(dayKey: String, parentID: UUID, subtaskID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Empty text on commit deletes the empty subtask (consistent with insertEmptySubtask flow).
            deleteSubtask(dayKey: dayKey, parentID: parentID, subtaskID: subtaskID)
            return
        }
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }),
              let s = bucket.tasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        bucket.tasks[p].subtasks[s].text = trimmed
        days[dayKey] = bucket
        save()
    }

    /// Toggles a subtask's done state, sinks completed subtasks to the bottom of the parent's
    /// subtask array. Returns true if the parent's subtasks are now all-done (caller can use
    /// this to drive parent auto-completion if the user has the setting enabled).
    @discardableResult
    func toggleSubtaskDone(dayKey: String, parentID: UUID, subtaskID: UUID, reorder: Bool = true) -> Bool {
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }),
              let s = bucket.tasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return false }
        bucket.tasks[p].subtasks[s].isDone.toggle()
        bucket.tasks[p].subtasks[s].completedAt = bucket.tasks[p].subtasks[s].isDone ? Date() : nil
        if reorder {
            normalizeSubtasksOrder(&bucket.tasks[p].subtasks)
        }
        let allDone = !bucket.tasks[p].subtasks.isEmpty && bucket.tasks[p].subtasks.allSatisfy { $0.isDone }
        days[dayKey] = bucket
        save()
        return allDone
    }

    func deleteSubtask(dayKey: String, parentID: UUID, subtaskID: UUID) {
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }) else { return }
        bucket.tasks[p].subtasks.removeAll { $0.id == subtaskID }
        days[dayKey] = bucket
        save()
    }

    /// Cmd+↑ / Cmd+↓ on a subtask: swap with adjacent sibling within the same done-state group.
    /// direction: -1 = up, +1 = down. No-op if the subtask is at the boundary of its group.
    func moveSubtask(dayKey: String, parentID: UUID, subtaskID: UUID, direction: Int) {
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }),
              let s = bucket.tasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        let subs = bucket.tasks[p].subtasks
        let newIdx = s + direction
        guard newIdx >= 0, newIdx < subs.count else { return }
        // Keep completed subtasks sunk to the bottom: only allow swaps within the same done group.
        guard subs[s].isDone == subs[newIdx].isDone else { return }
        bucket.tasks[p].subtasks.swapAt(s, newIdx)
        days[dayKey] = bucket
        save()
    }

    /// Tab key: convert a top-level task into a subtask of the top-level task immediately above
    /// it in bucket.tasks. Preserves id so selection tracks through the change.
    /// No-op if there is no task above, or if the task itself has subtasks (depth cap).
    @discardableResult
    func indentTaskAsSubtask(dayKey: String, taskID: UUID) -> UUID? {
        guard var bucket = days[dayKey],
              let i = bucket.tasks.firstIndex(where: { $0.id == taskID }),
              i > 0 else { return nil }
        guard bucket.tasks[i].subtasks.isEmpty else { return nil }
        let task = bucket.tasks[i]
        let parentIndex = i - 1
        let sub = Subtask(id: task.id,
                          text: task.text,
                          isDone: task.isDone,
                          createdAt: task.createdAt,
                          completedAt: task.completedAt)
        bucket.tasks.remove(at: i)
        bucket.tasks[parentIndex].subtasks.append(sub)
        normalizeSubtasksOrder(&bucket.tasks[parentIndex].subtasks)
        days[dayKey] = bucket
        normalizeOrder(dayKey: dayKey)
        save()
        return sub.id
    }

    /// Shift+Tab on a subtask: promote it to a top-level task positioned immediately after the
    /// parent and its remaining subtasks (i.e. right after the parent's slot in bucket.tasks).
    /// Preserves id and completion state.
    func unindentSubtaskToTask(dayKey: String, parentID: UUID, subtaskID: UUID) {
        guard var bucket = days[dayKey],
              let p = bucket.tasks.firstIndex(where: { $0.id == parentID }),
              let s = bucket.tasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        let sub = bucket.tasks[p].subtasks.remove(at: s)
        let task = TaskItem(id: sub.id,
                            text: sub.text,
                            isDone: sub.isDone,
                            createdAt: sub.createdAt,
                            completedAt: sub.completedAt,
                            subtasks: [])
        bucket.tasks.insert(task, at: p + 1)
        days[dayKey] = bucket
        normalizeOrder(dayKey: dayKey)
        save()
    }

    private func normalizeSubtasksOrder(_ subtasks: inout [Subtask]) {
        let undone = subtasks.filter { !$0.isDone }
        let done = subtasks.filter { $0.isDone }
        subtasks = undone + done
    }

    /// Merge imported subtasks into a parent: existing subtasks advance undone→done when the
    /// import is done; new subtasks append preserving import order.
    private func mergedSubtasks(local: [Subtask], imported: [Subtask]) -> [Subtask] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var order = local.map(\.id)
        var seen = Set(order)
        for sub in imported {
            if var existing = byID[sub.id] {
                if !existing.isDone && sub.isDone {
                    existing.isDone = true
                    existing.completedAt = sub.completedAt ?? Date()
                }
                byID[sub.id] = existing
            } else {
                byID[sub.id] = sub
                order.append(sub.id)
                seen.insert(sub.id)
            }
        }
        return order.compactMap { byID[$0] }
    }

    // MARK: - Later

    func moveTaskToLater(dayKey: String, taskID: UUID) {
        guard var bucket = days[dayKey],
              let i = bucket.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        var task = bucket.tasks.remove(at: i)
        task.isDone = false
        task.completedAt = nil
        laterTasks.append(task)
        days[dayKey] = bucket
        save()
        saveLater()
    }

    func moveTaskToToday(laterTaskID: UUID) {
        guard let i = laterTasks.firstIndex(where: { $0.id == laterTaskID }) else { return }
        var task = laterTasks.remove(at: i)
        task.createdAt = Date()
        task.isDone = false
        task.completedAt = nil

        let key = todayKey
        var bucket = days[key, default: DayBucket()]
        let insertIndex = bucket.tasks.firstIndex(where: { $0.isDone }) ?? bucket.tasks.count
        bucket.tasks.insert(task, at: insertIndex)
        days[key] = bucket

        save()
        saveLater()
    }

    func deleteLaterTask(taskID: UUID) {
        laterTasks.removeAll { $0.id == taskID }
        saveLater()
    }

    func moveLaterTask(taskID: UUID, direction: Int) {
        guard let idx = laterTasks.firstIndex(where: { $0.id == taskID }) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < laterTasks.count else { return }
        laterTasks.swapAt(idx, newIdx)
        saveLater()
    }

    func reorderLaterTasks(fromOffsets: IndexSet, toOffset: Int) {
        laterTasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveLater()
    }

    func updateLaterTaskText(taskID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let i = laterTasks.firstIndex(where: { $0.id == taskID }) else { return }
        laterTasks[i].text = trimmed
        saveLater()
    }

    // MARK: - Later subtasks

    /// Toggle a subtask's done state inside a Later parent. Completion sinks to the bottom of
    /// the parent's subtask array, matching the today-side behavior.
    func toggleLaterSubtaskDone(parentID: UUID, subtaskID: UUID) {
        guard let p = laterTasks.firstIndex(where: { $0.id == parentID }),
              let s = laterTasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        laterTasks[p].subtasks[s].isDone.toggle()
        laterTasks[p].subtasks[s].completedAt = laterTasks[p].subtasks[s].isDone ? Date() : nil
        normalizeSubtasksOrder(&laterTasks[p].subtasks)
        saveLater()
    }

    func updateLaterSubtaskText(parentID: UUID, subtaskID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteLaterSubtask(parentID: parentID, subtaskID: subtaskID)
            return
        }
        guard let p = laterTasks.firstIndex(where: { $0.id == parentID }),
              let s = laterTasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        laterTasks[p].subtasks[s].text = trimmed
        saveLater()
    }

    func deleteLaterSubtask(parentID: UUID, subtaskID: UUID) {
        guard let p = laterTasks.firstIndex(where: { $0.id == parentID }) else { return }
        laterTasks[p].subtasks.removeAll { $0.id == subtaskID }
        saveLater()
    }

    /// Cmd+↑/↓ on a Later subtask. Clamped to same-done-state siblings so completed subtasks
    /// stay pinned to the bottom.
    func moveLaterSubtask(parentID: UUID, subtaskID: UUID, direction: Int) {
        guard let p = laterTasks.firstIndex(where: { $0.id == parentID }),
              let s = laterTasks[p].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        let subs = laterTasks[p].subtasks
        let newIdx = s + direction
        guard newIdx >= 0, newIdx < subs.count else { return }
        guard subs[s].isDone == subs[newIdx].isDone else { return }
        laterTasks[p].subtasks.swapAt(s, newIdx)
        saveLater()
    }
}
