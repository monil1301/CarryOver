//
//  ImportExportService.swift
//  CarryOver
//

import Foundation

struct ExportPayload: Codable {
    let version: Int
    let exportedAt: Date
    let days: [String: DayBucket]
    let later: [TaskItem]
}

enum ImportError: LocalizedError {
    case unreadableFile
    case malformedJSON
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "Could not read the selected file."
        case .malformedJSON:
            return "The file is not a valid CarryOver export."
        case .unsupportedVersion(let v):
            return "This export was created by a newer version of CarryOver (version \(v)). Update the app and try again."
        }
    }
}

struct MergeSummary {
    var daysAdded: Int = 0
    var daysMerged: Int = 0
    var tasksAdded: Int = 0
    var tasksUpdated: Int = 0
    var laterAdded: Int = 0
    var laterUpdated: Int = 0
}

enum ImportExportService {
    static let currentVersion = 1

    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func encode(days: [String: DayBucket], later: [TaskItem]) throws -> Data {
        let payload = ExportPayload(
            version: currentVersion,
            exportedAt: Date(),
            days: days,
            later: later
        )
        return try makeEncoder().encode(payload)
    }

    static func decode(_ data: Data) throws -> ExportPayload {
        guard !data.isEmpty else { throw ImportError.malformedJSON }
        let payload: ExportPayload
        do {
            payload = try makeDecoder().decode(ExportPayload.self, from: data)
        } catch {
            throw ImportError.malformedJSON
        }
        if payload.version > currentVersion {
            throw ImportError.unsupportedVersion(payload.version)
        }
        return payload
    }

    static func defaultExportFilename(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "CarryOver-\(f.string(from: now)).json"
    }
}
