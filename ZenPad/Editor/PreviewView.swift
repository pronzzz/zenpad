import SwiftUI
import WebKit

/// Live Markdown preview. The page is loaded once; edits patch the content in place so the
/// preview never flickers or loses its scroll position.
struct PreviewView: NSViewRepresentable {
    @ObservedObject var prefs: Prefs
    @ObservedObject var session: EditorSession
    var isVisible: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = context.coordinator.makeWebView()
        context.coordinator.session = session
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let c = context.coordinator
        c.session = session
        c.update(css: PreviewStyle.css(PreviewStyle.options(from: prefs)))
        guard isVisible else { return }
        c.update(markdown: session.text, isMarkdown: session.isMarkdown, base: session.note?.url.deletingLastPathComponent())
        if prefs.syncPreviewScroll { c.scroll(to: session.scrollFraction) }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        weak var session: EditorSession?
        private var isLoaded = false
        private var lastMarkdown: String?
        private var lastCSS = ""
        private var lastBase: URL?
        private var lastFraction: CGFloat = -1
        private var pending: DispatchWorkItem?
        private var queued: [String] = []

        static let script = """
        window.zp = {
          update(html, base) {
            const main = document.getElementById('zp-content');
            if (base) { document.querySelector('base').setAttribute('href', base); }
            main.innerHTML = html;
          },
          style(css) { document.getElementById('zp-style').textContent = css; },
          scrollTo(f) {
            const max = document.documentElement.scrollHeight - window.innerHeight;
            window.scrollTo({ top: Math.max(0, max * f), behavior: 'instant' });
          },
          anchor(id) {
            const el = document.getElementById(id);
            if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        };
        document.addEventListener('click', (e) => {
          const t = e.target;
          if (t && t.matches('li.task > input[type=checkbox]')) {
            e.preventDefault();
            window.webkit.messageHandlers.zenpad.postMessage({ toggle: parseInt(t.dataset.line || '0', 10) });
          }
        }, true);
        """

        func makeWebView() -> WKWebView {
            let config = WKWebViewConfiguration()
            let controller = WKUserContentController()
            controller.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            controller.add(WeakMessageHandler(self), name: "zenpad")
            config.userContentController = controller
            config.preferences.isElementFullscreenEnabled = false
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.setValue(false, forKey: "drawsBackground")
            webView.navigationDelegate = self
            webView.allowsMagnification = true
            self.webView = webView
            loadShell(webView)
            return webView
        }

        /// Writes the page shell to Application Support so local images (relative to the note) can load.
        private func loadShell(_ webView: WKWebView) {
            let dir = Runtime.supportDirectory.appendingPathComponent("Preview", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("index.html")
            let html = PreviewStyle.document(body: "", css: lastCSS, title: "Preview")
            try? html.write(to: file, atomically: true, encoding: .utf8)
            webView.loadFileURL(file, allowingReadAccessTo: FileManager.default.homeDirectoryForCurrentUser)
        }

        func update(css: String) {
            guard css != lastCSS else { return }
            lastCSS = css
            run("zp.style(\(Self.jsString(css)))")
        }

        func update(markdown: String, isMarkdown: Bool, base: URL?) {
            guard markdown != lastMarkdown || base != lastBase else { return }
            let first = lastMarkdown == nil
            lastMarkdown = markdown
            lastBase = base
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let body: String
                if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body = "<p class=\"empty\">Nothing to preview yet.</p>"
                } else if isMarkdown {
                    body = MarkdownRenderer.html(from: markdown)
                } else {
                    body = "<pre><code>\(MarkdownRenderer.escape(markdown))</code></pre>"
                }
                let baseString = base.map { $0.absoluteString.hasSuffix("/") ? $0.absoluteString : $0.absoluteString + "/" }
                self.run("zp.update(\(Self.jsString(body)), \(baseString.map(Self.jsString) ?? "null"))")
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (first ? 0 : 0.12), execute: work)
        }

        func scroll(to fraction: CGFloat) {
            guard abs(fraction - lastFraction) > 0.001 else { return }
            lastFraction = fraction
            run("zp.scrollTo(\(fraction))")
        }

        func scrollToAnchor(_ id: String) {
            run("zp.anchor(\(Self.jsString(id)))")
        }

        private func run(_ js: String) {
            guard isLoaded, let webView else { queued.append(js); return }
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        static func jsString(_ s: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [s]), let json = String(data: data, encoding: .utf8) else { return "\"\"" }
            return String(json.dropFirst().dropLast())
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let pendingScripts = queued
            queued.removeAll()
            // Only the latest style/update calls matter.
            if let style = pendingScripts.last(where: { $0.hasPrefix("zp.style") }) { webView.evaluateJavaScript(style) }
            if let update = pendingScripts.last(where: { $0.hasPrefix("zp.update") }) { webView.evaluateJavaScript(update) }
            if let scroll = pendingScripts.last(where: { $0.hasPrefix("zp.scrollTo") }) { webView.evaluateJavaScript(scroll) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            if url.fragment != nil, url.path == webView.url?.path || url.scheme == "about" {
                if let fragment = url.fragment { scrollToAnchor(fragment) }
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL, Library.noteExtensions.contains(url.pathExtension.lowercased()) {
                AppModel.shared.open(url: url)
            } else {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let line = body["toggle"] as? Int, line > 0 else { return }
            session?.toggleTask(line: line)
        }
    }
}

/// Avoids the retain cycle WKUserContentController creates with its message handlers.
final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
