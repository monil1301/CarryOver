//
//  UpdaterService.swift
//  CarryOver
//

import AppKit
internal import Combine

// MARK: - Update State

enum UpdateState {
    case available(version: String)
    case downloading
    case readyToInstall
    case error(String)
}

// MARK: - Appcast Item

struct AppcastItem {
    let version: String          // sparkle:version (build number)
    let displayVersion: String   // sparkle:shortVersionString (marketing)
    let downloadURL: URL
}

// MARK: - Update Available ViewModel

@MainActor
final class UpdateAvailableViewModel: ObservableObject {
    @Published var state: UpdateState?
    var pendingItem: AppcastItem?
}

// MARK: - Self Updater

@MainActor
final class SelfUpdater {
    private let viewModel: UpdateAvailableViewModel
    private var autoCheckTimer: Timer?

    private var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    private var checkInterval: TimeInterval {
        let interval = Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? Int ?? 86400
        return TimeInterval(interval)
    }

    init(viewModel: UpdateAvailableViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Auto Check

    func startAutoChecks() {
        guard UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            await checkForUpdates(userInitiated: false)
        }
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates(userInitiated: false)
            }
        }
    }

    func stopAutoChecks() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil
    }

    // MARK: - Check

    func checkForUpdates(userInitiated: Bool) async {
        guard let item = await fetchLatestItem() else {
            if userInitiated { showNoUpdateAlert() }
            return
        }

        let currentBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "0"
        guard compareBuildVersions(current: currentBuild, latest: item.version) == .orderedAscending else {
            if userInitiated { showNoUpdateAlert() }
            return
        }

        viewModel.pendingItem = item
        viewModel.state = .available(version: item.displayVersion)

        if userInitiated {
            showUpdateAlert(item: item)
        }
    }

    // MARK: - Install

    func startUpdate() {
        guard let item = viewModel.pendingItem else { return }
        viewModel.state = .downloading

        Task.detached {
            do {
                let appPath = try await self.downloadAndExtract(url: item.downloadURL)
                await MainActor.run { self.viewModel.state = .readyToInstall }
                try self.replaceAndRelaunch(newAppPath: appPath)
            } catch {
                await MainActor.run {
                    self.viewModel.state = .error(error.localizedDescription)
                    self.showErrorAlert(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Appcast Parsing

    private func fetchLatestItem() async -> AppcastItem? {
        guard let url = URL(string: feedURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return AppcastParser.parse(data: data)
        } catch {
            return nil
        }
    }

    // MARK: - Version Comparison

    private func compareBuildVersions(current: String, latest: String) -> ComparisonResult {
        if let c = Int(current), let l = Int(latest) {
            if c < l { return .orderedAscending }
            if c > l { return .orderedDescending }
            return .orderedSame
        }
        return current.compare(latest, options: .numeric)
    }

    // MARK: - Download & Install

    private func downloadAndExtract(url: URL) async throws -> String {
        let (fileURL, _) = try await URLSession.shared.download(from: url)

        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CarryOverUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-xk", fileURL.path, extractDir.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }

        let appPath = extractDir.appendingPathComponent("CarryOver.app").path
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw UpdateError.appNotFound
        }
        return appPath
    }

    private nonisolated func replaceAndRelaunch(newAppPath: String) throws {
        let currentApp = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        let scriptPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("carryover_update.sh").path
        let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf '\(currentApp)'
            cp -R '\(newAppPath)' '\(currentApp)'
            open '\(currentApp)'
            rm -f '\(scriptPath)'
            """
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try process.run()

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Alerts

    private func showUpdateAlert(item: AppcastItem) {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        let alert = NSAlert()
        alert.messageText = "A new version of CarryOver is available!"
        alert.informativeText = "CarryOver \(item.displayVersion) is now available — you have \(currentVersion). Would you like to download it now?"
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            startUpdate()
        }
    }

    private func showNoUpdateAlert() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "CarryOver \(currentVersion) is currently the newest version available."
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case extractionFailed
    case appNotFound
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .extractionFailed: "Failed to extract update."
        case .appNotFound: "App not found in update archive."
        case .installFailed(let msg): "Installation failed: \(msg)"
        }
    }
}

// MARK: - Appcast XML Parser

private final class AppcastParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var sparkleVersion = ""
    private var shortVersionString = ""
    private var downloadURL = ""
    private var insideItem = false

    static func parse(data: Data) -> AppcastItem? {
        let parser = AppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        guard !parser.sparkleVersion.isEmpty,
              !parser.downloadURL.isEmpty,
              let url = URL(string: parser.downloadURL) else {
            return nil
        }

        return AppcastItem(
            version: parser.sparkleVersion,
            displayVersion: parser.shortVersionString.isEmpty ? parser.sparkleVersion : parser.shortVersionString,
            downloadURL: url
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentElement = qName ?? elementName
        if elementName == "item" { insideItem = true }
        if elementName == "enclosure", insideItem {
            downloadURL = attributes["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" { insideItem = false }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "sparkle:version": sparkleVersion += trimmed
        case "sparkle:shortVersionString": shortVersionString += trimmed
        default: break
        }
    }
}
