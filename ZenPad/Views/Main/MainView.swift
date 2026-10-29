import SwiftUI

/// The editor window: a translucent notes sidebar and a calm writing pane.
struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var prefs: Prefs

    var body: some View {
        HStack(spacing: 0) {
            if prefs.showSidebar && !model.focusMode {
                SidebarView(model: model)
                    .frame(width: 250)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Rectangle().fill(Color.zenHairline).frame(width: 1)
                    .transition(.opacity)
            }
            EditorPane(model: model, prefs: prefs, session: model.session)
        }
        .background(Color.zenPaper)
        .ignoresSafeArea()
        .animation(.zenSpring, value: prefs.showSidebar)
        .animation(.zenSpring, value: model.focusMode)
        .sheet(isPresented: $model.showTemplates) {
            TemplatePicker(model: model)
        }
    }
}

struct EditorPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var prefs: Prefs
    @ObservedObject var session: EditorSession
    @State private var headerHovered = false

    private var sidebarVisible: Bool { prefs.showSidebar && !model.focusMode }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(model: model, prefs: prefs, session: session, sidebarVisible: sidebarVisible)
                .opacity(model.focusMode && !headerHovered ? 0 : 1)
                .onHover { h in withAnimation(.zenFade) { headerHovered = h } }
                .zIndex(1)

            GeometryReader { geo in
                let fraction = prefs.editorMode.editorFraction
                HStack(spacing: 0) {
                    EditorView(prefs: prefs, session: session, focusMode: model.focusMode)
                        .frame(width: max(0, geo.size.width * fraction))
                        .opacity(fraction == 0 ? 0 : 1)
                        .allowsHitTesting(fraction > 0)
                    Rectangle()
                        .fill(Color.zenHairline)
                        .frame(width: fraction > 0 && fraction < 1 ? 1 : 0)
                    PreviewView(prefs: prefs, session: session, isVisible: fraction < 1)
                        .frame(width: max(0, geo.size.width * (1 - fraction) - (fraction > 0 && fraction < 1 ? 1 : 0)))
                        .opacity(fraction == 1 ? 0 : 1)
                }
                .animation(.zenSpring, value: prefs.editorMode)
            }

            if !model.focusMode {
                StatusBar(session: session)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if model.showAI {
                AIPanel(model: model, session: session)
                    .padding(.top, 46)
                    .padding(.trailing, 12)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing))))
            }
        }
        .animation(.zenSpring, value: model.showAI)
        .onExitCommand { if model.focusMode { model.toggleFocus() } else if model.showAI { model.showAI = false } }
    }
}

struct HeaderBar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var prefs: Prefs
    @ObservedObject var session: EditorSession
    var sidebarVisible: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !sidebarVisible {
                IconButton(symbol: "sidebar.left", help: "Show Sidebar (⌃⌘S)") { model.toggleSidebar() }
                    .padding(.leading, 74)
                    .transition(.opacity)
            } else {
                IconButton(symbol: "sidebar.left", help: "Hide Sidebar (⌃⌘S)") { model.toggleSidebar() }
                    .padding(.leading, 6)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(session.note?.title ?? "ZenPad")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                if let note = session.note, note.isExternal {
                    Text(note.url.deletingLastPathComponent().lastPathComponent)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.zenFade, value: session.note?.url)

            Spacer(minLength: 8)

            OutlineMenu(session: session)
            FontMenu(prefs: prefs)
            ModePicker(mode: Binding(get: { prefs.editorMode }, set: { model.setMode($0) }))
                .padding(.horizontal, 4)
            IconButton(symbol: model.focusMode ? "moon.fill" : "moon", help: "Focus Mode (⇧⌘F)", isActive: model.focusMode) {
                model.toggleFocus()
            }
            IconButton(symbol: "sparkles", help: "Writing Assistant (⇧⌘A)", isActive: model.showAI) {
                model.showAI.toggle()
            }
            MoreMenu(model: model, session: session)
                .padding(.trailing, 8)
        }
        .frame(height: 40)
        .background(Color.zenPaper.opacity(0.001))
    }
}

struct OutlineMenu: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        Menu {
            let headings = session.headings
            if headings.isEmpty {
                Text("No headings yet")
            } else {
                ForEach(Array(headings.enumerated()), id: \.offset) { _, h in
                    Button(String(repeating: "    ", count: max(0, h.level - 1)) + h.title) {
                        session.textView?.scrollToLine(h.line)
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Outline")
    }
}

struct FontMenu: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Menu {
            Section("System Fonts") {
                ForEach(FontCatalog.designs) { choice in fontButton(choice) }
            }
            Section("More Fonts") {
                ForEach(FontCatalog.curatedFamilies.filter { $0.kind != .mono }) { choice in fontButton(choice) }
            }
            Divider()
            Button("Bigger") { prefs.adjustFontSize(by: 1) }
            Button("Smaller") { prefs.adjustFontSize(by: -1) }
            Picker("Line Width", selection: $prefs.lineWidth) {
                ForEach(LineWidth.allCases) { Text($0.label).tag($0) }
            }
            Divider()
            Button("All Fonts & Typography…") { SettingsWindowController.shared.show(tab: .editor) }
        } label: {
            Text("Aa")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Font: \(FontCatalog.displayName(for: prefs.fontID))")
    }

    @ViewBuilder private func fontButton(_ choice: FontChoice) -> some View {
        Button {
            prefs.fontID = choice.id
        } label: {
            if prefs.fontID == choice.id {
                Label(choice.name, systemImage: "checkmark")
            } else {
                Text(choice.name)
            }
        }
    }
}

struct MoreMenu: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: EditorSession

    var body: some View {
        Menu {
            Button("New from Template…") { model.showTemplates = true }
            Divider()
            Button("Export as PDF…") { Exporter.shared.exportPDF() }
            Button("Export as HTML…") { Exporter.shared.exportHTML() }
            Button("Copy as HTML") { Exporter.shared.copyHTML() }
            Button("Print…") { Exporter.shared.printNote() }
            if let note = session.note {
                Divider()
                ShareLink(item: note.url) { Text("Share…") }
                Button("Show in Finder") { model.reveal(note) }
                Button("Duplicate") { model.duplicate(note) }
                Divider()
                Button("Move to Trash", role: .destructive) { model.moveToTrash(note) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }
}

struct StatusBar: View {
    @ObservedObject var session: EditorSession
    @State private var typing = false
    @State private var resetWork: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 14) {
            Text("\(session.stats.words.formatted()) words")
            Text("\(session.stats.characters.formatted()) characters")
            Text(session.stats.readingTime)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(session.isDirty ? Color.orange : Color.green.opacity(0.8))
                    .frame(width: 5, height: 5)
                Text(session.isDirty ? "Editing" : "Saved")
            }
            .animation(.zenFade, value: session.isDirty)
            Text(session.isMarkdown ? "Markdown" : "Plain Text")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.horizontal, 16)
        .frame(height: 26)
        .opacity(typing ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.35), value: typing)
        .onChange(of: session.lastTyped) {
            typing = true
            resetWork?.cancel()
            let work = DispatchWorkItem { typing = false }
            resetWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
        }
    }
}
