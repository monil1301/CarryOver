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
    @Published private(set) var days: [String: DayBucket] = [:]
    @Published var resetToken: Int = 0

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var todayKey: String { df.string(from: Date()) }

    private var fileURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("CarryOver", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            days = try JSONDecoder().decode([String: DayBucket].self, from: data)
        } catch {
            days = [:]
        }
        rolloverUnfinishedToToday()
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
    func rolloverUnfinishedToToday() {
        let today = todayKey
        var incoming: [TaskItem] = []

        for (dayKey, bucket) in days {
            guard dayKey < today else { continue } // works because yyyy-MM-dd
            let undone = bucket.tasks.filter { !$0.isDone }
            if !undone.isEmpty {
                incoming.append(contentsOf: undone)
                let doneOnly = bucket.tasks.filter { $0.isDone }
                days[dayKey]?.tasks = doneOnly
            }
        }

        if !incoming.isEmpty {
            days[today, default: DayBucket()].tasks = incoming + (days[today]?.tasks ?? [])
        }

        normalizeOrder(dayKey: today)
        save()
    }
    
    func dayKey(for date: Date) -> String { df.string(from: date) }

    func date(fromKey key: String) -> Date? { df.date(from: key) }

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

    func restoreBucket(dayKey: String, bucket: DayBucket) {
        days[dayKey] = bucket
        save()
    }
}
