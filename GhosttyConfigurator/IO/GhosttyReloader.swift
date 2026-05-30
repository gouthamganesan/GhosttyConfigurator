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
                let message = (String(bytes: data, encoding: .utf8) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ReloadError.osascriptFailed(message)
            }
        }.value

        Logger.app.info("sent reload_config keybind to Ghostty")
    }

    /// Click Ghostty's "Check for Updates…" menu item via AppleScript. No
    /// default keybind exists for `check_for_updates`, so a menu click is
    /// the lightest-weight way to trigger it without modifying user config.
    /// Same accessibility-permission prompt as `reload()`.
    @MainActor
    static func checkForUpdates() async throws {
        guard ConfigPaths.ghosttyAppURL() != nil else {
            throw ReloadError.ghosttyNotInstalled
        }
        let wasRunning = isGhosttyRunning
        if !wasRunning {
            // Launching activates Ghostty's menu bar; otherwise the System
            // Events click below silently no-ops.
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Ghostty.app"))
        }

        let script = """
        tell application "Ghostty" to activate
        delay 0.2
        tell application "System Events"
            tell process "Ghostty"
                click menu item "Check for Updates…" of menu 1 of menu bar item "Ghostty" of menu bar 1
            end tell
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
                let message = (String(bytes: data, encoding: .utf8) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ReloadError.osascriptFailed(message)
            }
        }.value

        Logger.app.info("clicked Check for Updates… in Ghostty menu")
    }
}
