//
//  TaskItem.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isDone: Bool
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
