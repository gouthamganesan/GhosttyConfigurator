import Foundation
import os

/// File-system watcher that emits a `()` value on every change event for a
/// single file. Bridges Apple's `DispatchSource` API to `AsyncStream` so
/// callers can `for await` events with structured cancellation.
///
/// Typical use from `ConfigStore.task`:
///
///     for await _ in FileWatcher.events(for: fileURL) {
///         await reloadIfChanged()
///     }
final class FileWatcher: @unchecked Sendable {
    /// Stream of change events for `url`. The stream terminates when the file
    /// is deleted and stays terminated — callers should restart it manually
    /// if the file reappears.
    static func events(for url: URL) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let fd = open(url.path, O_EVTONLY)
            guard fd >= 0 else {
                Logger.watcher
                    .error(
                        "open(O_EVTONLY) failed for \(url.path, privacy: .public): \(String(cString: strerror(errno)))"
                    )
                continuation.finish()
                return
            }

            let queue = DispatchQueue(label: "com.gouthamj.ghostty-configurator.filewatcher")
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .delete, .rename],
                queue: queue
            )

            source.setEventHandler { [weak source] in
                guard let source else { return }
                let event = source.data
                if event.contains(.delete) || event.contains(.rename) {
                    Logger.watcher.info("file deleted/renamed; ending stream")
                    continuation.finish()
                } else {
                    continuation.yield(())
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            continuation.onTermination = { _ in
                source.cancel()
            }

            source.resume()
        }
    }
}
