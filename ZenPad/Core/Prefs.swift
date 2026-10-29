import AppKit
import Combine

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum EditorMode: String, CaseIterable, Identifiable {
    case write, split, preview
    var id: String { rawValue }
    var label: String {
        switch self {
        case .write: return "Write"
        case .split: return "Split"
        case .preview: return "Preview"
        }
    }
    var symbol: String {
        switch self {
        case .write: return "square.and.pencil"
        case .split: return "rectangle.split.2x1"
        case .preview: return "eye"
        }
    }
    /// Share of the width the editor takes in this mode.
    var editorFraction: CGFloat {
        switch self {
        case .write: return 1
        case .split: return 0.5
        case .preview: return 0
        }
    }
}

enum LineWidth: String, CaseIterable, Identifiable {
    case narrow, medium, wide, full
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// Maximum text column width in points; nil fills the window.
    var points: CGFloat? {
        switch self {
        case .narrow: return 580
        case .medium: return 700
        case .wide: return 880
        case .full: return nil
        }
    }
}

enum LaunchBehavior: String, CaseIterable, Identifiable {
    case quickPad, editor, menuBar
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quickPad: return "Show Quick Pad"
        case .editor: return "Open the editor window"
        case .menuBar: return "Stay quietly in the menu bar"
        }
    }
}

/// User preferences, persisted in UserDefaults. Demo mode uses a separate, throwaway suite.
final class Prefs: ObservableObject {
    static let shared = Prefs()

    let store: UserDefaults

    @Published var appearance: AppearanceMode { didSet { store.set(appearance.rawValue, forKey: "appearance"); applyAppearance() } }
    @Published var fontID: String { didSet { store.set(fontID, forKey: "fontID") } }
    @Published var codeFontID: String { didSet { store.set(codeFontID, forKey: "codeFontID") } }
    @Published var fontSize: Double { didSet { store.set(fontSize, forKey: "fontSize") } }
    @Published var lineHeight: Double { didSet { store.set(lineHeight, forKey: "lineHeight") } }
    @Published var lineWidth: LineWidth { didSet { store.set(lineWidth.rawValue, forKey: "lineWidth") } }
    @Published var editorMode: EditorMode { didSet { store.set(editorMode.rawValue, forKey: "editorMode") } }
    @Published var showSidebar: Bool { didSet { store.set(showSidebar, forKey: "showSidebar") } }
    @Published var typewriterScrolling: Bool { didSet { store.set(typewriterScrolling, forKey: "typewriterScrolling") } }
    @Published var focusDimming: Bool { didSet { store.set(focusDimming, forKey: "focusDimming") } }
    @Published var spellCheck: Bool { didSet { store.set(spellCheck, forKey: "spellCheck") } }
    @Published var styleMarkdown: Bool { didSet { store.set(styleMarkdown, forKey: "styleMarkdown") } }
    @Published var syncPreviewScroll: Bool { didSet { store.set(syncPreviewScroll, forKey: "syncPreviewScroll") } }
    @Published var libraryPath: String { didSet { store.set(libraryPath, forKey: "libraryPath") } }
    @Published var launchBehavior: LaunchBehavior { didSet { store.set(launchBehavior.rawValue, forKey: "launchBehavior") } }
    @Published var showMenuBarIcon: Bool { didSet { store.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    @Published var autoCheckUpdates: Bool { didSet { store.set(autoCheckUpdates, forKey: "autoCheckUpdates") } }
    @Published var includePrereleases: Bool { didSet { store.set(includePrereleases, forKey: "includePrereleases") } }
    @Published var skippedVersion: String { didSet { store.set(skippedVersion, forKey: "skippedVersion") } }
    @Published var lastUpdateCheck: Date? { didSet { store.set(lastUpdateCheck, forKey: "lastUpdateCheck") } }
    @Published var ollamaURL: String { didSet { store.set(ollamaURL, forKey: "ollamaURL") } }
    @Published var ollamaModel: String { didSet { store.set(ollamaModel, forKey: "ollamaModel") } }
    @Published var hasLaunchedBefore: Bool { didSet { store.set(hasLaunchedBefore, forKey: "hasLaunchedBefore") } }

    static var defaultLibraryPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZenPad", isDirectory: true).path
    }

    private init() {
        if Runtime.isDemo || Runtime.isTesting {
            let suite = "com.zenpad.app.ephemeral"
            UserDefaults().removePersistentDomain(forName: suite)
            store = UserDefaults(suiteName: suite) ?? .standard
        } else {
            store = .standard
        }
        let s = store
        appearance = AppearanceMode(rawValue: s.string(forKey: "appearance") ?? "") ?? .system
        fontID = s.string(forKey: "fontID") ?? FontCatalog.defaultFontID
        codeFontID = s.string(forKey: "codeFontID") ?? "mono"
        fontSize = s.object(forKey: "fontSize") as? Double ?? 16
        lineHeight = s.object(forKey: "lineHeight") as? Double ?? 1.45
        lineWidth = LineWidth(rawValue: s.string(forKey: "lineWidth") ?? "") ?? .medium
        editorMode = EditorMode(rawValue: s.string(forKey: "editorMode") ?? "") ?? .write
        showSidebar = s.object(forKey: "showSidebar") as? Bool ?? true
        typewriterScrolling = s.object(forKey: "typewriterScrolling") as? Bool ?? false
        focusDimming = s.object(forKey: "focusDimming") as? Bool ?? true
        spellCheck = s.object(forKey: "spellCheck") as? Bool ?? true
        styleMarkdown = s.object(forKey: "styleMarkdown") as? Bool ?? true
        syncPreviewScroll = s.object(forKey: "syncPreviewScroll") as? Bool ?? true
        libraryPath = s.string(forKey: "libraryPath") ?? Prefs.defaultLibraryPath
        launchBehavior = LaunchBehavior(rawValue: s.string(forKey: "launchBehavior") ?? "") ?? .quickPad
        showMenuBarIcon = s.object(forKey: "showMenuBarIcon") as? Bool ?? true
        autoCheckUpdates = s.object(forKey: "autoCheckUpdates") as? Bool ?? true
        includePrereleases = s.object(forKey: "includePrereleases") as? Bool ?? false
        skippedVersion = s.string(forKey: "skippedVersion") ?? ""
        lastUpdateCheck = s.object(forKey: "lastUpdateCheck") as? Date
        ollamaURL = s.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        ollamaModel = s.string(forKey: "ollamaModel") ?? "llama3.2"
        hasLaunchedBefore = s.bool(forKey: "hasLaunchedBefore")
    }

    func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func adjustFontSize(by delta: Double) {
        fontSize = min(32, max(11, fontSize + delta))
    }
}
