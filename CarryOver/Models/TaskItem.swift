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
    var subtasks: [Subtask]

    init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil, subtasks: [Subtask] = []) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.subtasks = subtasks
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, isDone, createdAt, completedAt, subtasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
    }
}
