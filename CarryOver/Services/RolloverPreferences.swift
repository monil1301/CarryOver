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
}
