import AppKit
import Foundation
import os

/// Triggers Ghostty to reload its config by activating the app and sending
/// `⌘⇧,` (the default `reload_config` keybind).
///
/// First invocation prompts macOS for accessibility permission so this app
/// can post keystrokes to another process. We surface a clear error if the
/// user denies — the configurator still writes config files just fine without
/// this, the user just has to ⌘⇧, manually.
enum GhosttyReloader {
    enum ReloadError: Error, CustomStringConvertible {
        case ghosttyNotRunning
        case ghosttyNotInstalled
        case osascriptFailed(String)

        var description: String {
            switch self {
            case .ghosttyNotRunning: "Ghostty isn't running."
            case .ghosttyNotInstalled: "Ghostty isn't installed."
            case let .osascriptFailed(m): "Reload failed: \(m)"
            }
        }
    }

    /// True if a Ghostty process is currently running on this Mac.
    static var isGhosttyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.mitchellh.ghostty"
        }
    }

    /// Activate Ghostty and send the reload keybind. Returns void on success,
    /// throws otherwise. Must run from MainActor for NSWorkspace activation.
    @MainActor
    static func reload() async throws {
        guard ConfigPaths.ghosttyAppURL() != nil else {
            throw ReloadError.ghosttyNotInstalled
        }
        guard isGhosttyRunning else {
            throw ReloadError.ghosttyNotRunning
        }

        let script = """
        tell application "Ghostty" to activate
        delay 0.1
        tell application "System Events"
            keystroke "," using {command down, shift down}
        end tell
        """

        try await Task.detached {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            let err = Pipe()
            task.standardError = err
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let data = err.fileHandleForReading.readDataToEndOfFile()
                let message = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ReloadError.osascriptFailed(message)
            }
        }.value

        Logger.app.info("sent reload_config keybind to Ghostty")
    }
}
