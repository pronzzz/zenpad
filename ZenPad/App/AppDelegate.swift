import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var openedFilesAtLaunch = false
    private var didFinishLaunching = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Prefs.shared.applyAppearance()
        NSApp.mainMenu = MainMenu.build()
        guard !Runtime.isTesting else { return }
        if Runtime.isDemo { DemoContent.prepare() }
        Library.shared.start()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Runtime.isTesting else { return }
        let prefs = Prefs.shared
        if prefs.showMenuBarIcon { StatusItemController.shared.install() }

        HotkeyCenter.shared.handler = { action in
            switch action {
            case .quickPad: QuickPadController.shared.toggle()
            case .editor: MainWindowController.shared.toggle()
            }
        }
        if !Runtime.isDemo { HotkeyCenter.shared.start() }
        Updater.shared.startAutomaticChecks()
        didFinishLaunching = true

        if Runtime.isDemo {
            DemoContent.runScene()
            return
        }
        if openedFilesAtLaunch { return }
        if !prefs.hasLaunchedBefore {
            prefs.hasLaunchedBefore = true
            MainWindowController.shared.show()
            return
        }
        guard !LoginItem.launchedAtLogin else { return }
        switch prefs.launchBehavior {
        case .quickPad: DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { QuickPadController.shared.show() }
        case .editor: MainWindowController.shared.show()
        case .menuBar: break
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.show()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if !didFinishLaunching { openedFilesAtLaunch = true }
        for url in urls { AppModel.shared.open(url: url) }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !Runtime.isTesting else { return }
        Library.shared.scheduleReload()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        EditorSession.shared.saveNow()
        QuickPadController.shared.saveScratch()
        return .terminateNow
    }

    // MARK: Menu actions (nil-targeted, so they reach the app delegate through the responder chain)

    @objc func showAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(string: "A quiet place to write.\nMarkdown notes, a menu bar Quick Pad and a local AI assistant.",
                                         attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func checkForUpdates(_ sender: Any?) { Task { await Updater.shared.check(userInitiated: true) } }
    @objc func showSettings(_ sender: Any?) { SettingsWindowController.shared.show() }
    @objc func newNote(_ sender: Any?) { MainWindowController.shared.show(); AppModel.shared.newNote() }
    @objc func newFromTemplate(_ sender: Any?) { MainWindowController.shared.show(); AppModel.shared.showTemplates = true }
    @objc func openDocument(_ sender: Any?) { AppModel.shared.showOpenPanel() }
    @objc func saveNote(_ sender: Any?) { EditorSession.shared.saveNow() }
    @objc func saveNoteAs(_ sender: Any?) { AppModel.shared.saveAs() }
    @objc func duplicateNote(_ sender: Any?) { if let note = EditorSession.shared.note { AppModel.shared.duplicate(note) } }
    @objc func exportPDF(_ sender: Any?) { Exporter.shared.exportPDF() }
    @objc func exportHTML(_ sender: Any?) { Exporter.shared.exportHTML() }
    @objc func printNote(_ sender: Any?) { Exporter.shared.printNote() }
    @objc func searchNotes(_ sender: Any?) { MainWindowController.shared.show(); AppModel.shared.focusSearch() }
    @objc func modeWrite(_ sender: Any?) { AppModel.shared.setMode(.write) }
    @objc func modeSplit(_ sender: Any?) { AppModel.shared.setMode(.split) }
    @objc func modePreview(_ sender: Any?) { AppModel.shared.setMode(.preview) }
    @objc func toggleSidebarPane(_ sender: Any?) { AppModel.shared.toggleSidebar() }
    @objc func toggleFocusMode(_ sender: Any?) { AppModel.shared.toggleFocus() }
    @objc func toggleTypewriter(_ sender: Any?) { Prefs.shared.typewriterScrolling.toggle() }
    @objc func toggleAssistant(_ sender: Any?) { AppModel.shared.showAI.toggle() }
    @objc func fontBigger(_ sender: Any?) { Prefs.shared.adjustFontSize(by: 1) }
    @objc func fontSmaller(_ sender: Any?) { Prefs.shared.adjustFontSize(by: -1) }
    @objc func fontReset(_ sender: Any?) { Prefs.shared.fontSize = 16 }
    @objc func showQuickPad(_ sender: Any?) { QuickPadController.shared.show() }
    @objc func showEditor(_ sender: Any?) { MainWindowController.shared.show() }
    @objc func openWebsite(_ sender: Any?) { NSWorkspace.shared.open(URL(string: "https://github.com/pronzzz/zenpad")!) }
    @objc func openReleaseNotes(_ sender: Any?) { NSWorkspace.shared.open(Updater.shared.releasesPage) }
    @objc func reportIssue(_ sender: Any?) { NSWorkspace.shared.open(URL(string: "https://github.com/pronzzz/zenpad/issues/new")!) }
    @objc func markdownGuide(_ sender: Any?) { NSWorkspace.shared.open(URL(string: "https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax")!) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let prefs = Prefs.shared
        let model = AppModel.shared
        let hasNote = EditorSession.shared.note != nil && MainWindowController.shared.isVisible
        switch menuItem.action {
        case #selector(modeWrite(_:)): menuItem.state = prefs.editorMode == .write ? .on : .off; return MainWindowController.shared.isVisible
        case #selector(modeSplit(_:)): menuItem.state = prefs.editorMode == .split ? .on : .off; return MainWindowController.shared.isVisible
        case #selector(modePreview(_:)): menuItem.state = prefs.editorMode == .preview ? .on : .off; return MainWindowController.shared.isVisible
        case #selector(toggleSidebarPane(_:)):
            menuItem.title = prefs.showSidebar ? "Hide Sidebar" : "Show Sidebar"
            return MainWindowController.shared.isVisible && !model.focusMode
        case #selector(toggleFocusMode(_:)): menuItem.state = model.focusMode ? .on : .off; return MainWindowController.shared.isVisible
        case #selector(toggleTypewriter(_:)): menuItem.state = prefs.typewriterScrolling ? .on : .off; return true
        case #selector(toggleAssistant(_:)): menuItem.state = model.showAI ? .on : .off; return MainWindowController.shared.isVisible
        case #selector(saveNote(_:)), #selector(saveNoteAs(_:)), #selector(duplicateNote(_:)),
             #selector(exportPDF(_:)), #selector(exportHTML(_:)), #selector(printNote(_:)):
            return hasNote
        default:
            return true
        }
    }
}
