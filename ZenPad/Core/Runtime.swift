import Foundation

/// Process-level facts: demo/screenshot mode, tests, and command-line options.
enum Runtime {
    static let arguments = ProcessInfo.processInfo.arguments

    /// `--demo` runs against a throwaway library and preferences (used to render README screenshots).
    static let isDemo = arguments.contains("--demo")

    static let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Value following a `--name` argument, if present.
    static func value(for name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(isDemo ? "ZenPad-Demo" : "ZenPad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}
