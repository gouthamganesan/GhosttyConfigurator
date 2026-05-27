#!/usr/bin/env bash
# Bootstrap the Xcode project from project.yml.
# Idempotent — safe to run any time the project structure changes.

set -euo pipefail

cd "$(dirname "$0")/.."

# --- xcodegen ---
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "==> xcodegen not found. Installing via Homebrew…"
    if ! command -v brew >/dev/null 2>&1; then
        echo "ERROR: Homebrew not found. Install from https://brew.sh first." >&2
        exit 1
    fi
    brew install xcodegen
fi

# --- swiftformat / swiftlint (best-effort, not required) ---
for tool in swiftformat swiftlint; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "==> $tool not installed (optional). Install with: brew install $tool"
    fi
done

# --- generate project ---
echo "==> Generating GhosttyConfigurator.xcodeproj from project.yml…"
xcodegen generate

# --- open if requested ---
if [[ "${1:-}" == "--open" ]]; then
    echo "==> Opening Xcode…"
    open GhosttyConfigurator.xcodeproj
fi

echo
echo "✓ Project generated."
echo "  Open in Xcode:   open GhosttyConfigurator.xcodeproj"
echo "  Or build from CLI: xcodebuild -scheme GhosttyConfigurator -configuration Debug build"
