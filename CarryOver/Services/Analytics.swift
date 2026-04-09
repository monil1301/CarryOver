//
//  Analytics.swift
//  CarryOver
//

import Foundation
internal import TelemetryDeck

enum Analytics {
    static let telemetryAppID = "2D1E23A2-F888-4922-81FB-BE02EC3B2CEC"

    static func initialize() {
        let config = TelemetryDeck.Config(appID: telemetryAppID)
        TelemetryDeck.initialize(config: config)
    }

    static func send(_ name: String, with properties: [String: String] = [:]) {
        guard UserDefaults.standard.object(forKey: "analytics.enabled") as? Bool ?? true else { return }
        var params = defaultMetadata()
        params.merge(properties) { _, new in new }
        TelemetryDeck.signal(name, parameters: params)
    }

    private static func defaultMetadata() -> [String: String] {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return [
            "appVersion": appVersion,
            "macOSVersion": osVersion,
        ]
    }
}
