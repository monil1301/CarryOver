//
//  DayBucket.swift
//  CarryOver
//
//  Created by Monil Shah on 07/03/26.
//

import Foundation

struct DayBucket: Codable, Equatable {
    var tasks: [TaskItem] = []
    var note: String = "" 
}
