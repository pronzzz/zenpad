import Foundation

/// CSS shared by the live preview and HTML/PDF exports.
enum PreviewStyle {
    struct Options {
        var bodyFont: String
        var codeFont: String
        var fontSize: Double
        var lineHeight: Double
        var maxWidth: Double?
        var forPrint = false
    }

    @MainActor static func options(from prefs: Prefs, forPrint: Bool = false) -> Options {
        Options(bodyFont: FontCatalog.css(for: prefs.fontID), codeFont: FontCatalog.css(for: prefs.codeFontID),
                fontSize: prefs.fontSize, lineHeight: max(1.4, prefs.lineHeight + 0.15),
                maxWidth: prefs.lineWidth.points.map(Double.init), forPrint: forPrint)
    }

    static func css(_ o: Options) -> String {
        let width = o.maxWidth.map { "\(Int($0))px" } ?? "none"
        return """
        :root {
          color-scheme: light dark;
          --bg: #fdfdfa; --fg: #1f2126; --muted: #6b6f76; --faint: rgba(31,33,38,.1);
          --code-bg: rgba(31,33,38,.045); --accent: #3c7dff; --mark: rgba(255, 214, 10, .35);
          --tok-k: #ad3da4; --tok-s: #c41a16; --tok-c: #8a8f98; --tok-n: #1c00cf; --tok-t: #3f6e74; --tok-f: #326d9e; --tok-p: #836c28;
          --note: #3c7dff; --tip: #1f9d55; --important: #8250df; --warning: #b7791f; --caution: #d1242f;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #1c1c1e; --fg: #e6e6e3; --muted: #9a9ea6; --faint: rgba(255,255,255,.1);
            --code-bg: rgba(255,255,255,.06); --accent: #6199ff; --mark: rgba(255, 214, 10, .28);
            --tok-k: #ff7ab2; --tok-s: #ff8170; --tok-c: #7f8c98; --tok-n: #d9c97c; --tok-t: #8ad1c3; --tok-f: #67b7a4; --tok-p: #e5b567;
            --note: #6199ff; --tip: #3fb950; --important: #a371f7; --warning: #d29922; --caution: #f85149;
          }
        }
        * { box-sizing: border-box; }
        html { -webkit-text-size-adjust: 100%; }
        body {
          margin: 0; padding: \(o.forPrint ? "0" : "28px 40px 120px");
          background: \(o.forPrint ? "white" : "var(--bg)"); color: var(--fg);
          font-family: \(o.bodyFont); font-size: \(o.fontSize)px; line-height: \(o.lineHeight);
          -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility;
          word-wrap: break-word;
        }
        main { max-width: \(width); margin: 0 auto; }
        main > :first-child { margin-top: 0; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.6em 0 .55em; font-weight: 650; letter-spacing: -.01em; }
        h1 { font-size: 1.85em; } h2 { font-size: 1.45em; } h3 { font-size: 1.2em; } h4 { font-size: 1.05em; }
        h5, h6 { font-size: .95em; color: var(--muted); }
        p, ul, ol, blockquote, pre, .table-wrap, .alert { margin: 0 0 1em; }
        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 650; }
        del { color: var(--muted); }
        mark { background: var(--mark); color: inherit; border-radius: 3px; padding: 0 2px; }
        hr { border: 0; height: 1px; background: var(--faint); margin: 2em 0; }
        img { max-width: 100%; border-radius: 8px; }
        ul, ol { padding-left: 1.5em; }
        li { margin: .2em 0; }
        li > p { margin: 0; }
        li > ul, li > ol { margin: .2em 0; }
        ul.tasks { list-style: none; padding-left: .2em; }
        li.task { display: flex; gap: .55em; align-items: baseline; }
        li.task > input { flex: none; margin: 0; transform: translateY(.1em); accent-color: var(--accent); width: 1em; height: 1em; cursor: pointer; }
        li.task.done > p, li.task.done { color: var(--muted); }
        li.task.done > p { text-decoration: line-through; text-decoration-color: var(--faint); }
        blockquote { padding: .1em 1em; border-left: 3px solid var(--faint); color: var(--muted); }
        blockquote > :last-child { margin-bottom: 0; }
        code { font-family: \(o.codeFont); font-size: .86em; background: var(--code-bg); padding: .12em .38em; border-radius: 5px; }
        pre { position: relative; font-family: \(o.codeFont); background: var(--code-bg); padding: 14px 16px; border-radius: 10px; overflow-x: auto; line-height: 1.5; }
        pre code { background: none; padding: 0; font-size: .84em; white-space: pre; }
        pre .code-lang { position: absolute; top: 6px; right: 10px; font-size: 10px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); font-family: -apple-system, sans-serif; }
        .tok-k { color: var(--tok-k); } .tok-s { color: var(--tok-s); } .tok-c { color: var(--tok-c); font-style: italic; }
        .tok-n { color: var(--tok-n); } .tok-t { color: var(--tok-t); } .tok-f { color: var(--tok-f); } .tok-p, .tok-a { color: var(--tok-p); }
        .tok-add { color: var(--tip); } .tok-del { color: var(--caution); }
        .table-wrap { overflow-x: auto; }
        table { border-collapse: collapse; font-size: .94em; min-width: 50%; }
        th, td { border-bottom: 1px solid var(--faint); padding: .45em .9em; text-align: left; }
        th { font-weight: 600; border-bottom-width: 2px; }
        tr:last-child td { border-bottom: 0; }
        .alert { padding: .7em 1em; border-left: 3px solid var(--note); border-radius: 0 8px 8px 0; background: var(--code-bg); }
        .alert > :last-child { margin-bottom: 0; }
        .alert-title { font-weight: 650; font-size: .9em; margin-bottom: .3em; }
        .alert-note { border-color: var(--note); } .alert-note .alert-title { color: var(--note); }
        .alert-tip { border-color: var(--tip); } .alert-tip .alert-title { color: var(--tip); }
        .alert-important { border-color: var(--important); } .alert-important .alert-title { color: var(--important); }
        .alert-warning { border-color: var(--warning); } .alert-warning .alert-title { color: var(--warning); }
        .alert-caution { border-color: var(--caution); } .alert-caution .alert-title { color: var(--caution); }
        sup.fn-ref a { font-size: .75em; padding: 0 .1em; }
        .footnotes { font-size: .88em; color: var(--muted); margin-top: 3em; }
        .footnotes hr { margin: 0 0 1em; }
        .fn-back { margin-left: .2em; }
        .empty { color: var(--muted); text-align: center; margin-top: 30vh; font-family: -apple-system, sans-serif; font-size: 14px; }
        @media print {
          body { padding: 0; background: white; color: black; }
          pre, code { background: #f4f4f2 !important; }
          a { color: black; text-decoration: underline; }
          h1, h2, h3 { break-after: avoid; } pre, table, img { break-inside: avoid; }
        }
        """
    }

    /// Content-Security-Policy for the live preview: no scripts from the page, no network fetches.
    static let csp = "default-src 'none'; img-src * data: file:; style-src 'unsafe-inline'; font-src * data: file:; media-src * file:;"

    static func document(body: String, css: String, title: String, baseURL: URL? = nil, csp: Bool = true) -> String {
        let base = baseURL.map { "<base href=\"\(MarkdownRenderer.escape($0.absoluteString))\">" } ?? "<base href=\"about:blank\">"
        let policy = csp ? "<meta http-equiv=\"Content-Security-Policy\" content=\"\(PreviewStyle.csp)\">" : ""
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        \(policy)
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(base)
        <title>\(MarkdownRenderer.escape(title))</title>
        <style id="zp-style">\(css)</style>
        </head>
        <body><main id="zp-content">\(body)</main></body>
        </html>
        """
    }
}
