import AppKit

// ZenPad uses an AppKit lifecycle so it can start as a menu bar app (no Dock icon)
// and only become a regular app while the editor window is open.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}
