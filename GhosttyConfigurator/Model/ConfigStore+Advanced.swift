import Foundation
import SwiftUI

/// A3c — Advanced sub-sections (Custom shaders, Splits, Links). Pure
/// forwarding to the same scalar helpers other accessors use; lives in
/// its own file to keep `ConfigStore.swift` under the line-length cap.
@MainActor
extension ConfigStore {
    // MARK: - Custom shaders

    /// `custom-shader` — list-typed. Today we only surface the first entry
    /// for editing; users with multiple shaders chained can hand-edit the
    /// config file (the configurator preserves order on round-trip).
    var customShaderPath: String {
        get { file.listValues(for: "custom-shader").first ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                deleteKey("custom-shader", label: "Clear Custom Shader")
            } else {
                setScalar("custom-shader", value: trimmed, label: "Change Custom Shader")
            }
        }
    }

    var customShaderAnimation: CustomShaderAnimation {
        get {
            guard let raw = file.scalarValue(for: "custom-shader-animation"), !raw.isEmpty else {
                return .enabled
            }
            return CustomShaderAnimation(rawValue: raw) ?? .enabled
        }
        set {
            if newValue == .enabled {
                deleteKey("custom-shader-animation", label: "Reset Shader Animation")
            } else {
                setScalar("custom-shader-animation", value: newValue.rawValue, label: "Change Shader Animation")
            }
        }
    }

    // MARK: - Splits

    /// `unfocused-split-opacity` — Ghostty clamps to [0.15, 1]. UI does the
    /// same so we never round-trip a value Ghostty would reject.
    var unfocusedSplitOpacity: Double {
        get { file.double(for: "unfocused-split-opacity", default: 0.7) }
        set { setDouble("unfocused-split-opacity", max(0.15, min(1.0, newValue)), label: "Change Split Opacity") }
    }

    var unfocusedSplitFill: Color {
        get { file.color(for: "unfocused-split-fill") ?? .black }
        set { setScalar(
            "unfocused-split-fill",
            value: ColorParsing.hexString(from: newValue),
            label: "Change Unfocused Split Fill"
        ) }
    }

    var isUnfocusedSplitFillAuto: Bool {
        get { file.scalarValue(for: "unfocused-split-fill") == nil }
        set {
            if newValue {
                deleteKey("unfocused-split-fill", label: "Reset Unfocused Split Fill")
            } else {
                setScalar(
                    "unfocused-split-fill",
                    value: ColorParsing.hexString(from: Color.black),
                    label: "Set Unfocused Split Fill"
                )
            }
        }
    }

    var splitDividerColor: Color {
        get { file.color(for: "split-divider-color") ?? .gray }
        set { setScalar(
            "split-divider-color",
            value: ColorParsing.hexString(from: newValue),
            label: "Change Split Divider Color"
        ) }
    }

    var isSplitDividerColorAuto: Bool {
        get { file.scalarValue(for: "split-divider-color") == nil }
        set {
            if newValue {
                deleteKey("split-divider-color", label: "Reset Split Divider Color")
            } else {
                setScalar(
                    "split-divider-color",
                    value: ColorParsing.hexString(from: Color.gray),
                    label: "Set Split Divider Color"
                )
            }
        }
    }

    // MARK: - Links

    /// `link-url` — single toggle for the built-in URL link matcher. The
    /// regex-driven custom `link` entries are out of scope; users can
    /// hand-edit those in the config file (preserved on round-trip).
    var linkUrl: Bool {
        get { file.bool(for: "link-url", default: true) }
        set { setBool("link-url", newValue, label: "Toggle URL Linking") }
    }
}
