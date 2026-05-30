import Foundation
import os

extension Logger {
    private static let subsystem = "com.gouthamj.ghostty-configurator"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let parser = Logger(subsystem: subsystem, category: "parser")
    static let watcher = Logger(subsystem: subsystem, category: "watcher")
    static let themes = Logger(subsystem: subsystem, category: "themes")
    static let launch = Logger(subsystem: subsystem, category: "launch")
}
