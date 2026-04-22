//
//  SubtaskPreferences.swift
//  CarryOver
//
//  Created by Monil Shah on 22/04/26.
//

import Foundation

enum SubtaskPreferences {
    static let autoCompleteParentKey = "subtask.autoCompleteParent"

    static func currentAutoCompleteParent() -> Bool {
        UserDefaults.standard.bool(forKey: autoCompleteParentKey)
    }
}
