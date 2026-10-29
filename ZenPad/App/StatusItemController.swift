import AppKit

/// The ensō in the menu bar. Left-click toggles the Quick Pad; right-click shows a menu.
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var item: NSStatusItem?

    var buttonScreenFrame: NSRect? {
        guard let button = item?.button, let window = button.window, window.isVisible else { return nil }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        // Right after launch (or when the menu bar is too crowded to show the icon) the frame is
        // not on any screen's menu bar yet; callers then fall back to the top of the main screen.
        guard frame.width > 0, NSScreen.screens.contains(where: { $0.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) && frame.minY > $0.visibleFrame.maxY - 4 }) else { return nil }
        return frame
    }

    func install() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "ZenPadStatusItem"
        if let button = item.button {
            button.image = MenuBarIcon.image()
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "ZenPad"
        }
        self.item = item
    }

    func remove() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    func setHighlighted(_ on: Bool) {
        item?.button?.highlight(on)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            QuickPadController.shared.toggle()
        }
    }

    private func showMenu() {
        QuickPadController.shared.hide(animated: false)
        let menu = NSMenu()
        menu.addItem(withTitle: "Quick Pad", action: #selector(quickPad), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Open ZenPad", action: #selector(openEditor), keyEquivalent: "").target = self
        menu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ZenPad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item?.menu = menu
        item?.button?.performClick(nil)
        item?.menu = nil
    }

    @objc private func quickPad() { QuickPadController.shared.show() }
    @objc private func openEditor() { MainWindowController.shared.show() }
    @objc private func newNote() { MainWindowController.shared.show(); AppModel.shared.newNote() }
    @objc private func settings() { SettingsWindowController.shared.show() }
    @objc private func checkUpdates() { Task { await Updater.shared.check(userInitiated: true) } }
}
