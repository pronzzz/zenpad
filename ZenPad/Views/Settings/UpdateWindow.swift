import AppKit
import SwiftUI
import WebKit

final class UpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = UpdateWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: UpdateView(updater: .shared))
            host.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        if !MainWindowController.shared.isVisible {
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

struct UpdateView: View {
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let release = currentRelease, !release.notes.isEmpty {
                ReleaseNotesView(markdown: release.notes)
                    .frame(height: 260)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.zenHairline))
            }
            if case let .downloading(_, progress) = updater.state {
                ProgressView(value: progress) { Text("Downloading…").font(.caption) }
                    .transition(.opacity)
            }
            if case .installing = updater.state {
                ProgressView { Text("Verifying and installing…").font(.caption) }
                    .progressViewStyle(.linear)
            }
            buttons
        }
        .padding(22)
        .padding(.top, 8)
        .frame(width: 540)
        .animation(.zenSpring, value: updater.state)
    }

    private var currentRelease: ReleaseInfo? {
        switch updater.state {
        case .available(let r), .downloading(let r, _), .installing(let r): return r
        default: return nil
        }
    }

    private var title: String {
        switch updater.state {
        case .available(let r), .downloading(let r, _), .installing(let r): return "ZenPad \(r.version) is available"
        case .upToDate: return "You're up to date"
        case .checking: return "Checking for updates…"
        case .failed: return "Update problem"
        case .idle: return "Software Update"
        }
    }

    private var subtitle: String {
        switch updater.state {
        case .available(let r):
            let base = "You have \(Runtime.appVersion)."
            return updater.canInstallInPlace || r.zipURL == nil ? base : base + " Move ZenPad to your Applications folder to update automatically."
        case .downloading, .installing: return "ZenPad will restart when the update is ready."
        case .upToDate: return "ZenPad \(Runtime.appVersion) is the newest version."
        case .checking: return "Contacting GitHub…"
        case .failed(let message): return message
        case .idle: return ""
        }
    }

    @ViewBuilder private var buttons: some View {
        HStack {
            switch updater.state {
            case .available(let release):
                Button("Skip This Version") { updater.skip(release); UpdateWindowController.shared.close() }
                Spacer()
                Button("Remind Me Later") { UpdateWindowController.shared.close() }
                    .keyboardShortcut(.cancelAction)
                Button(updater.canInstallInPlace && release.zipURL != nil ? "Install and Relaunch" : "Download") {
                    updater.downloadAndInstall(release)
                }
                .keyboardShortcut(.defaultAction)
            case .downloading:
                Spacer()
                Button("Cancel") { updater.cancelDownload() }
            case .installing:
                Spacer()
            default:
                Link("Release notes", destination: updater.releasesPage).font(.system(size: 12))
                Spacer()
                Button("OK") { UpdateWindowController.shared.close() }.keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// Renders release notes (Markdown) with the preview stylesheet.
struct ReleaseNotesView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loaded != markdown else { return }
        context.coordinator.loaded = markdown
        var options = PreviewStyle.options(from: .shared)
        options.fontSize = 13
        options.bodyFont = FontCatalog.css(for: "system")
        options.maxWidth = nil
        let css = PreviewStyle.css(options) + " body { padding: 14px 18px; background: transparent; } h1 { font-size: 1.3em; } h2 { font-size: 1.12em; }"
        webView.loadHTMLString(PreviewStyle.document(body: MarkdownRenderer.html(from: markdown), css: css, title: "Release Notes"), baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
