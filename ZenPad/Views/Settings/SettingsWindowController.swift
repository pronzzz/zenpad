import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    enum Tab: Int, CaseIterable {
        case general, editor, shortcuts, assistant, updates
        var title: String {
            switch self {
            case .general: return "General"
            case .editor: return "Editor"
            case .shortcuts: return "Shortcuts"
            case .assistant: return "Assistant"
            case .updates: return "Updates"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .editor: return "textformat"
            case .shortcuts: return "command"
            case .assistant: return "sparkles"
            case .updates: return "arrow.triangle.2.circlepath"
            }
        }
    }

    private var window: NSWindow?
    private var tabs: NSTabViewController?

    func show(tab: Tab? = nil) {
        if window == nil { build() }
        if let tab { tabs?.selectedTabViewItemIndex = tab.rawValue }
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == false { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]
        for tab in Tab.allCases {
            let host = NSHostingController(rootView: AnyView(view(for: tab)))
            host.sizingOptions = .preferredContentSize
            host.title = tab.title // NSTabViewController shows the selected title in the window
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        self.tabs = tabs
    }

    @ViewBuilder private func view(for tab: Tab) -> some View {
        switch tab {
        case .general: GeneralSettings(prefs: .shared)
        case .editor: EditorSettings(prefs: .shared)
        case .shortcuts: ShortcutSettings()
        case .assistant: AssistantSettings(prefs: .shared)
        case .updates: UpdateSettings(prefs: .shared)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !MainWindowController.shared.isVisible {
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
