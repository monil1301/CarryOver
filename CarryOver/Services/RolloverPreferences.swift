//
//  RolloverPreferences.swift
//  CarryOver
//

import Foundation

enum RolloverPreferences {
    static let autoMoveToLaterDaysKey = "rollover.autoMoveToLaterDays"

    // 0 means Off / Never
    static let defaultAutoMoveToLaterDays = 5
    static let options: [Int] = [0, 3, 5, 7, 14, 30]

    static func currentThreshold() -> Int {
        if UserDefaults.standard.object(forKey: autoMoveToLaterDaysKey) == nil {
            return defaultAutoMoveToLaterDays
        }
        return UserDefaults.standard.integer(forKey: autoMoveToLaterDaysKey)
    }

    static func label(for days: Int) -> String {
        days == 0 ? "Off" : "\(days) days"
    }

    // MARK: - Rollover cutoff hour

    static let cutoffHourKey = "rollover.cutoffHour"
    static let defaultCutoffHour = 0 // 12 AM
    static let cutoffHourOptions: [Int] = [0, 1, 2, 3, 4, 5, 6]

    static func currentCutoffHour() -> Int {
        let raw: Int
        if UserDefaults.standard.object(forKey: cutoffHourKey) == nil {
            raw = defaultCutoffHour
        } else {
            raw = UserDefaults.standard.integer(forKey: cutoffHourKey)
        }
        return min(max(raw, 0), 6)
    }

    static func cutoffLabel(for hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return "\(hour)" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h a"
        return f.string(from: date)
    }
}
