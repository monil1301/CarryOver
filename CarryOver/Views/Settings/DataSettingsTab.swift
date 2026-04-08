//
//  DataSettingsTab.swift
//  CarryOver
//

import SwiftUI

struct DataSettingsTab: View {
    @State private var analyticsEnabled = UserDefaults.standard.object(forKey: "analytics.enabled") as? Bool ?? true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Privacy
            SettingsSection("Privacy") {
                Toggle("Send anonymous usage data", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "analytics.enabled")
                    }

                Text("Helps improve CarryOver. No personal data is ever collected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}
