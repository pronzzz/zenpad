import AppKit
import Combine
import SwiftUI

/// A borderless panel that can take keyboard focus without activating the app.
final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        QuickPadController.shared.hide()
    }
}

/// The small popover-style window under the menu bar icon: a scratch pad that's always one click away.
final class QuickPadController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = QuickPadController()

    static let size = NSSize(width: 384, height: 468)

    @Published var scratch: String
    @Published var appeared = false
    @Published var toast: String?

    weak var textView: ZenTextView?
    private var panel: QuickPanel?
    private var pendingSave: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?
    private var isHiding = false

    var isShown: Bool { panel?.isVisible == true && !isHiding }

    private var scratchURL: URL { Runtime.supportDirectory.appendingPathComponent("QuickPad.md") }

    private override init() {
        scratch = ""
        super.init()
        scratch = (try? String(contentsOf: scratchURL, encoding: .utf8)) ?? ""
    }

    // MARK: Panel

    private func makePanel() -> QuickPanel {
        let panel = QuickPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                               styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                               backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 14)
        effect.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: QuickPadView(controller: self, library: .shared))
        host.frame = effect.bounds
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)
        panel.contentView = effect
        return panel
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// Where the panel should sit: just under the menu bar icon, or top-centre if there's no icon.
    private func targetFrame() -> NSRect {
        let size = Self.size
        if let button = StatusItemController.shared.buttonScreenFrame,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(button) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            var x = button.midX - size.width / 2
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
            let y = button.minY - size.height - 6
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        return NSRect(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 12, width: size.width, height: size.height)
    }

    func toggle() {
        isShown ? hide() : show()
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        isHiding = false
        let final = targetFrame()
        panel.setFrame(final.offsetBy(dx: 0, dy: 10), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().setFrame(final, display: true)
            panel.animator().alphaValue = 1
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { appeared = true }
        StatusItemController.shared.setHighlighted(true)
        Library.shared.scheduleReload()
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.textView else { return }
            panel.makeFirstResponder(tv)
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
        }
    }

    func hide(animated: Bool = true) {
        guard let panel, panel.isVisible, !isHiding else { return }
        isHiding = true
        saveScratch()
        StatusItemController.shared.setHighlighted(false)
        withAnimation(.easeIn(duration: 0.14)) { appeared = false }
        let finish = { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1
            self?.isHiding = false
            // Give focus back to whatever the user was doing, unless the editor is open.
            if !MainWindowController.shared.isVisible && NSApp.windows.allSatisfy({ !$0.isVisible || $0 is NSPanel || !$0.canBecomeKey }) {
                NSApp.hide(nil)
            }
        }
        guard animated else { finish(); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: 6), display: true)
        }, completionHandler: { MainActor.assumeIsolated { finish() } })
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clicking elsewhere dismisses the pad, like a popover.
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, !panel.isKeyWindow, NSApp.modalWindow == nil else { return }
            if panel.attachedSheet == nil { self.hide() }
        }
    }

    // MARK: Content

    func scratchDidChange(_ text: String) {
        scratch = text
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveScratch() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveScratch() {
        pendingSave?.cancel()
        if let tv = textView { scratch = tv.string }
        try? scratch.write(to: scratchURL, atomically: true, encoding: .utf8)
    }

    /// Turns the scratch into a library note and clears the pad.
    func saveAsNote() {
        let text = (textView?.string ?? scratch).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = Library.shared.createNote(content: text + "\n")
        clear()
        showToast("Saved “\(note.title)”")
    }

    func clear() {
        if let tv = textView {
            tv.replace(NSRange(location: 0, length: (tv.string as NSString).length), with: "")
        }
        scratch = ""
        saveScratch()
    }

    /// Opens the full editor. A non-empty scratch comes along as a new note.
    func openInEditor() {
        let text = (textView?.string ?? scratch).trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = panel?.frame
        if !text.isEmpty {
            let note = Library.shared.createNote(content: text + "\n")
            clear()
            EditorSession.shared.open(note)
        }
        hide(animated: false)
        MainWindowController.shared.show(from: origin)
    }

    func open(_ note: Note) {
        let origin = panel?.frame
        EditorSession.shared.open(note)
        hide(animated: false)
        MainWindowController.shared.show(from: origin)
    }

    func showToast(_ message: String) {
        toastWork?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { toast = message }
        let work = DispatchWorkItem { [weak self] in withAnimation(.zenFade) { self?.toast = nil } }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}
