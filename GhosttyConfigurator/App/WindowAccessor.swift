import AppKit
import SwiftUI

/// Bridges an `NSWindow` callback into SwiftUI exactly once.
/// Used at the root to lock down zoom + fullscreen — the two pieces of window
/// chrome SwiftUI doesn't (yet) let us configure declaratively.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor [weak view] in
            guard let window = view?.window else { return }
            callback(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
