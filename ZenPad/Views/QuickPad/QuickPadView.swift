import SwiftUI

struct QuickPadView: View {
    @ObservedObject var controller: QuickPadController
    @ObservedObject var library: Library
    @ObservedObject var prefs = Prefs.shared

    private var words: Int { TextStats(controller.scratch).words }
    private var isEmpty: Bool { controller.scratch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            QuickEditor(controller: controller, prefs: prefs)
                .padding(.horizontal, 4)
                .frame(maxHeight: .infinity)
            if !library.notes.isEmpty {
                recent
            }
            footer
        }
        .frame(width: QuickPadController.size.width, height: QuickPadController.size.height)
        .scaleEffect(controller.appeared ? 1 : 0.965, anchor: .top)
        .opacity(controller.appeared ? 1 : 0)
        .overlay(alignment: .bottom) {
            if let toast = controller.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.regularMaterial))
                    .overlay(Capsule().strokeBorder(Color.zenHairline))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.bottom, 52)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZenGlyph(lineWidth: 1.8)
                .frame(width: 16, height: 16)
                .foregroundStyle(.primary)
            Text("Quick Pad")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            IconButton(symbol: "arrow.up.left.and.arrow.down.right", help: "Open in ZenPad (⌘O)", size: 12) {
                controller.openInEditor()
            }
            .keyboardShortcut("o", modifiers: .command)
            Menu {
                Button("Open ZenPad") { controller.openInEditor() }
                Button("New from Template…") {
                    controller.openInEditor()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { AppModel.shared.showTemplates = true }
                }
                Divider()
                Button("Settings…") { controller.hide(animated: false); SettingsWindowController.shared.show() }
                Button("Check for Updates…") { controller.hide(animated: false); Task { await Updater.shared.check(userInitiated: true) } }
                Divider()
                Button("Quit ZenPad") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 42)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            ForEach(library.notes.prefix(3)) { note in
                RecentRow(note: note) { controller.open(note) }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.zenHairline).frame(height: 1) }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(isEmpty ? "Jot it down, sort it later" : "\(words) word\(words == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.zenSnappy, value: words)
            Spacer()
            if !isEmpty {
                Button("Clear") { controller.clear() }
                    .controlSize(.small)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Button {
                controller.saveAsNote()
            } label: {
                HStack(spacing: 4) {
                    Text("Save Note")
                    Text("⌘↩").foregroundStyle(.white.opacity(0.7))
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .overlay(alignment: .top) { Rectangle().fill(Color.zenHairline).frame(height: 1) }
        .animation(.zenSnappy, value: isEmpty)
    }
}

private struct RecentRow: View {
    let note: Note
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text(note.title)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                Spacer()
                Text(note.modified.zenRelative)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(hovering ? 0.07 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { h in withAnimation(.zenFade) { hovering = h } }
    }
}

/// The Quick Pad's editor: the same Markdown-aware text view as the main window, smaller.
struct QuickEditor: NSViewRepresentable {
    @ObservedObject var controller: QuickPadController
    @ObservedObject var prefs: Prefs

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = ZenTextView.makeScrollable(theme: .quickPad(from: prefs))
        textView.placeholder = "What's on your mind?"
        textView.setText(controller.scratch)
        textView.onTextChange = { [weak controller] text in controller?.scratchDidChange(text) }
        textView.isContinuousSpellCheckingEnabled = prefs.spellCheck
        controller.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? ZenTextView else { return }
        textView.theme = .quickPad(from: prefs)
        textView.styleMarkdown = prefs.styleMarkdown
    }
}
