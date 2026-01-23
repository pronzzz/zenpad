import Foundation
import SwiftUI
import Combine

class Preferences: ObservableObject {
    static let shared = Preferences()
    
    private let defaults = UserDefaults.standard
    
    enum AppearanceMode: String, CaseIterable {
        case system, light, dark
    }
    
    // MARK: - General Settings
    @Published var appearanceMode: AppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
            updateAppearance()
        }
    }
    
    @Published var showWelcomeOnLaunch: Bool {
        didSet {
            defaults.set(showWelcomeOnLaunch, forKey: "showWelcomeOnLaunch")
        }
    }
    
    @Published var autoSaveEnabled: Bool {
        didSet {
            defaults.set(autoSaveEnabled, forKey: "autoSaveEnabled")
        }
    }
    
    @Published var autoSaveInterval: Double {
        didSet {
            defaults.set(autoSaveInterval, forKey: "autoSaveInterval")
        }
    }
    
    @Published var maxVersions: Int {
        didSet {
            defaults.set(maxVersions, forKey: "maxVersions")
        }
    }
    
    // MARK: - Editor Settings
    @Published var fontFamily: String {
        didSet {
            defaults.set(fontFamily, forKey: "fontFamily")
        }
    }
    
    @Published var fontSize: CGFloat {
        didSet {
            defaults.set(fontSize, forKey: "fontSize")
        }
    }
    
    @Published var lineHeight: CGFloat {
        didSet {
            defaults.set(lineHeight, forKey: "lineHeight")
        }
    }
    
    // MARK: - Computed Properties
    var editorFont: NSFont {
        if fontFamily == "System" {
            return .systemFont(ofSize: fontSize)
        } else if fontFamily == "SF Mono" {
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else {
            return NSFont(name: fontFamily, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
    
    var isDarkMode: Bool {
        switch appearanceMode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        case .light:
            return false
        case .dark:
            return true
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load saved values or use defaults
        self.appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "system") ?? .system
        self.showWelcomeOnLaunch = defaults.object(forKey: "showWelcomeOnLaunch") as? Bool ?? true
        self.autoSaveEnabled = defaults.object(forKey: "autoSaveEnabled") as? Bool ?? true
        self.autoSaveInterval = defaults.object(forKey: "autoSaveInterval") as? Double ?? 30.0
        self.maxVersions = defaults.object(forKey: "maxVersions") as? Int ?? 50
        self.fontFamily = defaults.string(forKey: "fontFamily") ?? "SF Mono"
        self.fontSize = defaults.object(forKey: "fontSize") as? CGFloat ?? 14.0
        self.lineHeight = defaults.object(forKey: "lineHeight") as? CGFloat ?? 1.5
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
