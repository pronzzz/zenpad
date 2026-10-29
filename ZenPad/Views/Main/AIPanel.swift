import SwiftUI

/// A floating card for the local writing assistant. Works on the selection, or the whole note.
struct AIPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: EditorSession
    @ObservedObject var ai = AIService.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var prompt = ""
    @State private var sourceRange = NSRange(location: 0, length: 0)
    @State private var sourceText = ""

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !ai.isConnected {
                offline
            } else {
                scopeLabel
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(AIService.Action.allCases) { action in
                        Button { run(action) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: action.symbol).font(.system(size: 13))
                                Text(action.label).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(ai.isRunning)
                    }
                }
                HStack(spacing: 6) {
                    TextField("Ask anything about this text…", text: $prompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .onSubmit { runCustom() }
                    Button(action: runCustom) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 17))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(prompt.isEmpty ? Color.secondary : Color.accentColor)
                    .disabled(prompt.isEmpty || ai.isRunning)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))

                if ai.isRunning || !ai.output.isEmpty || ai.errorMessage != nil {
                    result
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(VisualEffect(material: .popover, blending: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.zenHairline))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .animation(.zenSpring, value: ai.output.isEmpty)
        .animation(.zenSpring, value: ai.isRunning)
        .task { await ai.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
            Text("Writing Assistant").font(.system(size: 13, weight: .semibold))
            Spacer()
            Circle().fill(ai.isConnected ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
            Text(ai.isConnected ? prefs.ollamaModel : "Offline")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button { model.showAI = false } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var scopeLabel: some View {
        let selection = session.textView?.selectedRange() ?? NSRange(location: 0, length: 0)
        let words = selection.length > 0 ? TextStats((session.text as NSString).substring(with: selection)).words : session.stats.words
        return Text(selection.length > 0 ? "Using your selection · \(words) words" : "Using the whole note · \(words) words")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    private var offline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ZenPad's assistant runs on your Mac with Ollama, so your writing never leaves it.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Link("Get Ollama", destination: URL(string: "https://ollama.com/download")!)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Retry") { Task { await ai.refresh() } }
                    .controlSize(.small)
            }
            Text("Then run: ollama pull \(prefs.ollamaModel)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = ai.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    Text(ai.output.isEmpty ? "Thinking…" : ai.output)
                        .font(.system(size: 12.5))
                        .foregroundStyle(ai.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                if ai.isRunning {
                    ProgressView().controlSize(.small)
                    Spacer()
                    Button("Stop") { ai.cancel() }.controlSize(.small)
                } else if ai.errorMessage == nil {
                    Button(ai.lastAction?.replaces ?? true ? "Replace" : "Insert") { apply(replace: ai.lastAction?.replaces ?? true) }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    Button("Insert Below") { apply(replace: false) }.controlSize(.small)
                    Spacer()
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(ai.output, forType: .string) } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .controlSize(.small)
                    .help("Copy")
                    Button { ai.clear() } label: { Image(systemName: "trash") }
                        .controlSize(.small)
                        .help("Discard")
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func captureSource() {
        guard let tv = session.textView else { return }
        let ns = tv.string as NSString
        let selection = tv.selectedRange()
        if selection.length > 0 {
            sourceRange = selection
        } else {
            sourceRange = NSRange(location: 0, length: ns.length)
        }
        sourceText = ns.substring(with: sourceRange)
    }

    private func run(_ action: AIService.Action) {
        captureSource()
        ai.run(action, text: sourceText)
    }

    private func runCustom() {
        guard !prompt.isEmpty else { return }
        captureSource()
        ai.run(nil, text: sourceText, customPrompt: prompt)
        prompt = ""
    }

    private func apply(replace: Bool) {
        guard let tv = session.textView, !ai.output.isEmpty else { return }
        let ns = tv.string as NSString
        let result = ai.output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only replace if the source is still where we left it.
        let stillThere = NSMaxRange(sourceRange) <= ns.length && ns.substring(with: sourceRange) == sourceText
        if replace && stillThere {
            tv.replace(sourceRange, with: result, selection: NSRange(location: sourceRange.location, length: (result as NSString).length))
        } else {
            let at = stillThere ? NSMaxRange(sourceRange) : ns.length
            let insert = "\n\n" + result
            tv.replace(NSRange(location: at, length: 0), with: insert, selection: NSRange(location: at + 2, length: (result as NSString).length))
        }
        tv.window?.makeFirstResponder(tv)
        ai.clear()
    }
}
