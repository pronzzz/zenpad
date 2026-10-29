import AppKit

/// `ZenPad --demo --library <dir> --scene <name>` seeds sample notes and opens a given screen.
/// Used by scripts/screenshots.sh to render the README screenshots. Never touches real notes or settings.
enum DemoContent {
    static func prepare() {
        let prefs = Prefs.shared
        prefs.hasLaunchedBefore = true
        prefs.launchBehavior = .menuBar
        if let appearance = Runtime.value(for: "--appearance").flatMap(AppearanceMode.init(rawValue:)) { prefs.appearance = appearance }
        if let font = Runtime.value(for: "--font") { prefs.fontID = font }
        if let mode = Runtime.value(for: "--mode").flatMap(EditorMode.init(rawValue:)) { prefs.editorMode = mode }
        if let size = Runtime.value(for: "--font-size").flatMap(Double.init) { prefs.fontSize = size }
        prefs.showSidebar = Runtime.value(for: "--sidebar") != "off"
        prefs.spellCheck = false

        guard let path = Runtime.value(for: "--library") else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date()
        for (index, note) in notes.enumerated() {
            let url = dir.appendingPathComponent(note.0 + ".md")
            try? note.1.write(to: url, atomically: true, encoding: .utf8)
            let date = now.addingTimeInterval(-Double(index) * 3600 * 7 - 120)
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        let scratch = Runtime.supportDirectory.appendingPathComponent("QuickPad.md")
        try? quickPad.write(to: scratch, atomically: true, encoding: .utf8)
    }

    static func runScene() {
        let scene = Runtime.value(for: "--scene") ?? "editor"
        let model = AppModel.shared
        if let title = Runtime.value(for: "--note"), let note = Library.shared.notes.first(where: { $0.title.hasPrefix(title) }) {
            EditorSession.shared.open(note)
        }
        func showEditor() {
            MainWindowController.shared.show()
            // Applied after the opening animation, which would otherwise restore the saved frame.
            if let size = Runtime.value(for: "--size")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    MainWindowController.shared.window?.setFrame(NSRect(x: 120, y: 120, width: size[0], height: size[1]), display: true)
                }
            }
        }
        switch scene {
        case "quickpad":
            QuickPadController.shared.show()
        case "focus":
            showEditor()
            model.focusMode = true
            if let line = Runtime.value(for: "--line").flatMap(Int.init) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { EditorSession.shared.textView?.scrollToLine(line) }
            }
        case "templates":
            showEditor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.showTemplates = true }
        case "settings-editor":
            SettingsWindowController.shared.show(tab: .editor)
        case "settings-shortcuts":
            SettingsWindowController.shared.show(tab: .shortcuts)
        case "update":
            Updater.shared.demoAvailable()
        default:
            showEditor()
        }
        // Keep every window on the primary display so screenshots are rendered at the same scale.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let primary = NSScreen.screens.first?.visibleFrame else { return }
            for window in NSApp.windows where window.isVisible && window.frame.width > 200 && !primary.contains(window.frame) {
                let f = window.frame
                window.setFrameOrigin(NSPoint(x: primary.midX - f.width / 2, y: primary.maxY - f.height - 60))
            }
        }
    }

    static let quickPad = """
    Call Maya about the **offsite** before Friday
    - [x] Send the agenda
    - [ ] Book train tickets
    - [ ] Ask about a _vegetarian_ menu
    """

    static let notes: [(String, String)] = [
        ("Launch plan", """
        # Launch plan for v2.0

        A calm launch: ship the build, write the notes, then **step away from the keyboard**.

        ## This week
        - [x] Final icon and DMG background
        - [x] Release notes in `CHANGELOG.md`
        - [ ] Record a 30-second demo
        - [ ] Post to the [discussion board](https://github.com/pronzzz/zenpad)

        > [!TIP]
        > Updates now arrive straight from GitHub Releases, signed and verified.

        ## Timeline
        | Day | Milestone | Owner |
        | --- | :-------: | ----: |
        | Mon | Code freeze | Pranav |
        | Wed | Release candidate | Team |
        | Fri | Ship it | Everyone |

        ```swift
        let release = try await updater.check()
        if release.isNewer { await updater.install(release) }
        ```

        Questions go in the *#zenpad* channel.[^1]

        [^1]: Or reply to the launch email.
        """),
        ("Morning pages", """
        # Morning pages

        The house is quiet before seven. Coffee, a window, and nothing to answer yet.

        I keep coming back to the same idea: *the best tools disappear*. A pen doesn't ask for attention. A blank page doesn't send notifications.

        > Simplicity is not the absence of clutter; it's the presence of focus.

        Three things for today:

        1. Finish the chapter outline
        2. Walk without headphones
        3. Write one honest paragraph

        Everything else can wait until the afternoon.
        """),
        ("Reading list", """
        # Reading list

        ## Now
        - **The Creative Act** — Rick Rubin
        - *Four Thousand Weeks* — Oliver Burkeman

        ## Next
        - [ ] Draft No. 4 — John McPhee
        - [ ] Bird by Bird — Anne Lamott
        - [x] On Writing — Stephen King

        Notes live in [this folder](https://github.com/pronzzz/zenpad).
        """),
        ("Miso ramen", """
        # Miso ramen

        Serves two, about 40 minutes.

        ## Broth
        1. Sweat garlic, ginger and scallion whites in sesame oil
        2. Add 2 tbsp white miso and 1 tbsp tahini
        3. Whisk in 900 ml warm stock

        ## To finish
        - Soft-boiled eggs, ~~7~~ 6½ minutes
        - Corn, nori, chilli oil
        """),
        ("Ideas", """
        # Ideas

        - A *slow* newsletter: one letter a month, hand-edited
        - Typewriter mode that clicks — optional, obviously
        - ==Weekly review== template with three questions
        """),
        ("Welcome to ZenPad", WelcomeNote.text),
    ]
}

extension Updater {
    /// Shows the update window with sample data (screenshots only).
    func demoAvailable() {
        let notes = """
        ## What's new
        - **Quick Pad** — a tiny scratch pad under the menu bar icon
        - **Global shortcuts** to open ZenPad from anywhere
        - Full **GitHub Flavored Markdown**, live in the editor and preview
        - A new ensō icon and a calmer, lighter interface

        ## Fixes
        - The preview no longer flickers while you type
        """
        let release = ReleaseInfo(version: "2.1.0", name: "ZenPad 2.1.0", notes: notes, pageURL: releasesPage,
                                  zipURL: URL(string: "https://example.com/z.zip"), signatureURL: nil, dmgURL: nil,
                                  publishedAt: Date(), isPrerelease: false)
        setDemoState(.available(release))
        UpdateWindowController.shared.show()
    }
}
