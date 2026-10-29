import AppKit
import SwiftUI

/// The editor window. While it's open ZenPad is a regular app with a Dock icon; when it closes,
/// ZenPad goes back to living only in the menu bar.
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private(set) var window: NSWindow?

    var isVisible: Bool { window?.isVisible ?? false }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "ZenPad"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = NSToolbar(identifier: "ZenPadMain")
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 420)
        window.collectionBehavior = [.fullScreenPrimary]
        window.tabbingMode = .disallowed
        window.backgroundColor = Palette.paper
        window.delegate = self

        let host = NSHostingController(rootView: MainView(model: .shared, prefs: .shared))
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(NSSize(width: 1080, height: 720))
        if !window.setFrameUsingName("ZenPadMainWindow") { window.center() }
        window.setFrameAutosaveName("ZenPadMainWindow")
        return window
    }

    /// Opens (or focuses) the editor. `from` is a screen rect to grow out of, e.g. the Quick Pad.
    func show(from origin: NSRect? = nil) {
        let window = self.window ?? makeWindow()
        self.window = window
        AppModel.shared.ensureSelection()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let final = window.frame
        if let origin {
            // Grow out of the Quick Pad with a soft fade.
            window.alphaValue = 0
            window.setFrame(origin, display: false)
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                window.animator().setFrame(final, display: true)
                window.animator().alphaValue = 1
            }
        } else {
            window.alphaValue = 0
            let start = final.insetBy(dx: final.width * 0.015, dy: final.height * 0.015)
            window.setFrame(start, display: false)
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                window.animator().setFrame(final, display: true)
                window.animator().alphaValue = 1
            }
        }
    }

    func toggle() {
        if let window, window.isVisible, window.isKeyWindow, NSApp.isActive {
            window.performClose(nil)
        } else {
            show()
        }
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        EditorSession.shared.saveNow()
        AppModel.shared.focusMode = false
        DispatchQueue.main.async {
            // Back to a menu bar app, unless another regular window (Settings) still needs the Dock.
            let others = NSApp.windows.filter { $0.isVisible && $0 !== self.window && $0.canBecomeMain && !($0 is NSPanel) }
            if others.isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        Library.shared.scheduleReload()
        EditorSession.shared.reloadIfChangedOnDisk()
    }

    func windowDidResignKey(_ notification: Notification) {
        EditorSession.shared.saveNow()
    }
}
