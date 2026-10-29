import AppKit
import UniformTypeIdentifiers
import WebKit

/// Exports the open note as HTML or PDF, prints it, or copies it as HTML. Uses the preview renderer.
final class Exporter: NSObject, WKNavigationDelegate {
    static let shared = Exporter()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var onLoad: ((WKWebView) -> Void)?

    private var session: EditorSession { .shared }

    func document(forPrint: Bool) -> String? {
        guard let note = session.note else { return nil }
        let body = note.isMarkdown ? MarkdownRenderer.html(from: session.text) : "<pre>\(MarkdownRenderer.escape(session.text))</pre>"
        let css = PreviewStyle.css(PreviewStyle.options(from: .shared, forPrint: forPrint))
        return PreviewStyle.document(body: body, css: css, title: note.title, baseURL: note.url.deletingLastPathComponent(), csp: false)
    }

    func exportHTML() {
        guard let note = session.note, let html = document(forPrint: false) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = note.url.deletingPathExtension().lastPathComponent + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func copyHTML() {
        guard session.note != nil else { return }
        let html = MarkdownRenderer.html(from: session.text)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .html)
        pb.setString(html, forType: .string)
    }

    func exportPDF() {
        guard let note = session.note, let html = document(forPrint: true) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = note.url.deletingPathExtension().lastPathComponent + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(html) { [weak self] webView in
            let info = self?.printInfo() ?? NSPrintInfo()
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
            self?.run(webView.printOperation(with: info), showPanels: false) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    func printNote() {
        guard let html = document(forPrint: true) else { return }
        load(html) { [weak self] webView in
            guard let self else { return }
            self.run(webView.printOperation(with: self.printInfo()), showPanels: true) {}
        }
    }

    private func printInfo() -> NSPrintInfo {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 54
        info.bottomMargin = 54
        info.leftMargin = 60
        info.rightMargin = 60
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        return info
    }

    private func run(_ operation: NSPrintOperation, showPanels: Bool, completion: @escaping () -> Void) {
        operation.showsPrintPanel = showPanels
        operation.showsProgressPanel = showPanels
        // WKWebView needs a non-zero frame on the print view or it renders blank pages.
        operation.view?.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        guard let host = window else { return }
        operation.runModal(for: host, delegate: nil, didRun: nil, contextInfo: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion() }
    }

    /// Loads HTML in an off-screen web view, then calls back once it has rendered.
    private func load(_ html: String, then: @escaping (WKWebView) -> Void) {
        if window == nil {
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 816, height: 1056))
            webView.navigationDelegate = self
            let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 816, height: 1056), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = webView
            window.isReleasedWhenClosed = false
            self.window = window
            self.webView = webView
        }
        window?.orderBack(nil)
        onLoad = then
        webView?.loadHTMLString(html, baseURL: session.note?.url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let callback = onLoad
        onLoad = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { callback?(webView) }
    }
}
