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

    func addTaskToday(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let key = todayKey
        var bucket = days[key, default: DayBucket()]

        // Insert at the end of unfinished tasks (right before first done task)
        let insertIndex = bucket.tasks.firstIndex(where: { $0.isDone }) ?? bucket.tasks.count
        bucket.tasks.insert(TaskItem(text: t), at: insertIndex)

        days[key] = bucket
        save()
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
}
