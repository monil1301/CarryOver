//
//  DataSettingsTab.swift
//  CarryOver
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DataSettingsTab: View {
    let store: DailyStore

    @State private var analyticsEnabled = UserDefaults.standard.object(forKey: "analytics.enabled") as? Bool ?? true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Data
            SettingsSection("Data") {
                HStack(spacing: 8) {
                    Button("Export Tasks…") { exportTasks() }
                    Button("Import Tasks…") { importTasks() }
                }
                Text("Back up your tasks to a file, or import tasks from a previously-exported file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

    // MARK: - Export

    private func exportTasks() {
        let panel = NSSavePanel()
        panel.title = "Export CarryOver Tasks"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = ImportExportService.defaultExportFilename()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try store.exportPayloadData()
            try data.write(to: url, options: [.atomic])
            presentInfo("Export complete", detail: "Your tasks were exported to \(url.lastPathComponent).")
        } catch {
            presentError("Could not export tasks.", detail: error.localizedDescription)
        }
    }

    // MARK: - Import

    private func importTasks() {
        let panel = NSOpenPanel()
        panel.title = "Import CarryOver Tasks"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            presentError("Could not read file.", detail: error.localizedDescription)
            return
        }

        let payload: ExportPayload
        do {
            payload = try ImportExportService.decode(data)
        } catch let err as ImportError {
            presentError("Import failed.", detail: err.errorDescription ?? "Unknown error.")
            return
        } catch {
            presentError("Import failed.", detail: error.localizedDescription)
            return
        }

        let confirm = NSAlert()
        confirm.messageText = "Import tasks from \(url.lastPathComponent)?"
        confirm.informativeText = "This will merge \(payload.days.count) day(s) and \(payload.later.count) later task(s) into your current data. Completed tasks will never be marked incomplete."
        confirm.addButton(withTitle: "Import")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let summary = store.applyImport(payload: payload)
        presentInfo("Import complete", detail: summaryText(summary))
    }

    private func summaryText(_ s: MergeSummary) -> String {
        var parts: [String] = []
        if s.daysAdded > 0 { parts.append("\(s.daysAdded) new day(s)") }
        if s.daysMerged > 0 { parts.append("\(s.daysMerged) day(s) merged") }
        if s.tasksAdded > 0 { parts.append("\(s.tasksAdded) task(s) added") }
        if s.tasksUpdated > 0 { parts.append("\(s.tasksUpdated) task(s) marked done") }
        if s.laterAdded > 0 { parts.append("\(s.laterAdded) later task(s) added") }
        if s.laterUpdated > 0 { parts.append("\(s.laterUpdated) later task(s) marked done") }
        if parts.isEmpty { return "Nothing to import — your data is already up to date." }
        return "Imported: " + parts.joined(separator: ", ") + "."
    }

    private func presentError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentInfo(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
