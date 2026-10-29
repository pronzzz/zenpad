import Carbon.HIToolbox
import SwiftUI

private let settingsWidth: CGFloat = 520

struct GeneralSettings: View {
    @ObservedObject var prefs: Prefs
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Open ZenPad at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
                Picker("When ZenPad opens", selection: $prefs.launchBehavior) {
                    ForEach(LaunchBehavior.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Show icon in menu bar", isOn: $prefs.showMenuBarIcon)
                    .onChange(of: prefs.showMenuBarIcon) { _, on in
                        if on { StatusItemController.shared.install() } else { StatusItemController.shared.remove() }
                    }
                if !prefs.showMenuBarIcon {
                    Text("Use your keyboard shortcuts to reach ZenPad while the icon is hidden.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Picker("Appearance", selection: $prefs.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                LabeledContent("Notes folder") {
                    HStack {
                        Text(abbreviate(Library.shared.folderURL.path))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose…", action: chooseFolder)
                    }
                }
                Text("Notes are plain Markdown files. Pick a folder in iCloud Drive to sync them across your Macs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.directoryURL = Library.shared.folderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        EditorSession.shared.close()
        Library.shared.moveLibrary(to: url)
        AppModel.shared.ensureSelection()
    }
}

struct EditorSettings: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            Section {
                Picker("Font", selection: $prefs.fontID) {
                    Section("System") {
                        ForEach(FontCatalog.designs) { Text($0.name).tag($0.id) }
                    }
                    Section("Writing Fonts") {
                        ForEach(FontCatalog.curatedFamilies) { Text($0.name).tag($0.id) }
                    }
                    Section("All Fonts") {
                        ForEach(FontCatalog.allFamilies, id: \.self) { Text($0).tag("family:\($0)") }
                    }
                }
                Picker("Code font", selection: $prefs.codeFontID) {
                    ForEach(FontCatalog.monoChoices) { Text($0.name).tag($0.id) }
                    Divider()
                    ForEach(FontCatalog.allFamilies, id: \.self) { Text($0).tag("family:\($0)") }
                }
                sample
            }
            Section {
                LabeledContent("Size") {
                    HStack {
                        Slider(value: $prefs.fontSize, in: 11...32, step: 1)
                        Text("\(Int(prefs.fontSize)) pt").monospacedDigit().frame(width: 42, alignment: .trailing)
                    }
                }
                LabeledContent("Line height") {
                    HStack {
                        Slider(value: $prefs.lineHeight, in: 1.1...2.0, step: 0.05)
                        Text(String(format: "%.2f", prefs.lineHeight)).monospacedDigit().frame(width: 42, alignment: .trailing)
                    }
                }
                Picker("Line width", selection: $prefs.lineWidth) {
                    ForEach(LineWidth.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Style Markdown as you type", isOn: $prefs.styleMarkdown)
                Toggle("Check spelling while typing", isOn: $prefs.spellCheck)
                Toggle("Typewriter scrolling", isOn: $prefs.typewriterScrolling)
                Toggle("Dim other paragraphs in Focus Mode", isOn: $prefs.focusDimming)
                Toggle("Sync preview scrolling with the editor", isOn: $prefs.syncPreviewScroll)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var sample: some View {
        let font = FontCatalog.font(for: prefs.fontID, size: CGFloat(min(prefs.fontSize, 22)))
        return VStack(alignment: .leading, spacing: 4) {
            Text("Write without distraction.")
                .font(Font(font.with(bold: true)))
            Text("The quick brown fox jumps over the lazy dog — *and* `keeps going`.")
                .font(Font(font))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .animation(.zenFade, value: prefs.fontID)
    }
}

struct ShortcutSettings: View {
    @ObservedObject var center = HotkeyCenter.shared

    private let inApp: [(String, String)] = [
        ("New note", "⌘N"), ("New from template", "⇧⌘N"), ("Write / Split / Preview", "⌘1  ⌘2  ⌘3"),
        ("Focus mode", "⇧⌘F"), ("Toggle sidebar", "⌃⌘S"), ("Writing assistant", "⇧⌘A"),
        ("Bold / Italic", "⌘B  ⌘I"), ("Link / Inline code", "⌘K  ⇧⌘K"), ("Headings", "⌥⌘1–3"),
        ("Toggle task", "⇧⌘T"), ("Find / Replace", "⌘F  ⌥⌘F"), ("Save note (Quick Pad)", "⌘↩"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    LabeledContent(action.label) { ShortcutRecorder(action: action) }
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                HStack {
                    Text("These work from any app. Click to record, ⌫ to clear.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset to Defaults") { center.resetToDefaults() }.controlSize(.small)
                }
            }
            Section("In ZenPad") {
                ForEach(inApp, id: \.0) { item in
                    LabeledContent(item.0) {
                        Text(item.1).font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShortcutRecorder: View {
    let action: HotkeyAction
    @ObservedObject var center = HotkeyCenter.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Type shortcut…" : (center.combos[action]?.display ?? "Record Shortcut"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(recording ? Color.accentColor : (center.combos[action] == nil ? .secondary : .primary))
                    .frame(minWidth: 116)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.bordered)
            if center.combos[action] != nil && !recording {
                Button { center.set(nil, for: action) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
                    .help("Clear")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        center.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape { stop(); return nil }
            if Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete {
                center.set(nil, for: action); stop(); return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
                NSSound.beep()
                return nil
            }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: KeyCombo.carbonModifiers(from: flags), key: KeyCombo.keyName(for: event))
            center.set(combo, for: action)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { center.resume() }
        recording = false
    }
}

struct AssistantSettings: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var ai = AIService.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle().fill(ai.isConnected ? Color.green : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                        Text(ai.isConnected ? "Connected to Ollama" : "Ollama not running").foregroundStyle(.secondary)
                        Button("Refresh") { Task { await ai.refresh() } }.controlSize(.small)
                    }
                }
                TextField("Server", text: $prefs.ollamaURL)
                if ai.models.isEmpty {
                    TextField("Model", text: $prefs.ollamaModel)
                } else {
                    Picker("Model", selection: $prefs.ollamaModel) {
                        ForEach(ai.models, id: \.self) { Text($0).tag($0) }
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The writing assistant runs locally with Ollama. Your text never leaves your Mac.")
                    Link("Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .task { await ai.refresh() }
    }
}

struct UpdateSettings: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("ZenPad") {
                    Text("Version \(Runtime.appVersion) (\(Runtime.buildNumber))").foregroundStyle(.secondary)
                }
                Toggle("Check for updates automatically", isOn: $prefs.autoCheckUpdates)
                Toggle("Include pre-releases", isOn: $prefs.includePrereleases)
                LabeledContent("Last checked") {
                    HStack {
                        Text(prefs.lastUpdateCheck.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                            .foregroundStyle(.secondary)
                        Button(updater.state == .checking ? "Checking…" : "Check Now") {
                            Task { await updater.check(userInitiated: true) }
                        }
                        .disabled(updater.state == .checking)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updates come from GitHub Releases and are verified with an Ed25519 signature before they're installed.")
                    Link("Release notes", destination: updater.releasesPage)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}
