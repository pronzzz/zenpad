import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String
    @Binding var isDarkMode: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
    
    private func generateHTML(from markdown: String) -> String {
        let htmlContent = markdownToHTML(markdown)
        let textColor = isDarkMode ? "#e0e0e0" : "#1a1a1a"
        let backgroundColor = isDarkMode ? "#1e1e1e" : "#ffffff"
        let codeBackground = isDarkMode ? "#2d2d2d" : "#f5f5f5"
        let borderColor = isDarkMode ? "#404040" : "#e0e0e0"
        let linkColor = isDarkMode ? "#6db3f2" : "#0066cc"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: 15px;
                    line-height: 1.7;
                    color: \(textColor);
                    background-color: \(backgroundColor);
                    padding: 30px 40px;
                    margin: 0;
                    -webkit-font-smoothing: antialiased;
                }
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    line-height: 1.3;
                }
                h1 { font-size: 2em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                p { margin: 1em 0; }
                a { color: \(linkColor); text-decoration: none; }
                a:hover { text-decoration: underline; }
                code {
                    font-family: 'SF Mono', Menlo, Monaco, monospace;
                    font-size: 0.9em;
                    background-color: \(codeBackground);
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                }
                pre {
                    background-color: \(codeBackground);
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1em 0;
                }
                pre code {
                    background: none;
                    padding: 0;
                }
                blockquote {
                    border-left: 4px solid \(borderColor);
                    margin: 1em 0;
                    padding-left: 16px;
                    color: \(isDarkMode ? "#a0a0a0" : "#666666");
                }
                ul, ol {
                    padding-left: 2em;
                    margin: 1em 0;
                }
                li { margin: 0.25em 0; }
                hr {
                    border: none;
                    border-top: 1px solid \(borderColor);
                    margin: 2em 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                }
                th, td {
                    border: 1px solid \(borderColor);
                    padding: 8px 12px;
                    text-align: left;
                }
                th {
                    background-color: \(codeBackground);
                    font-weight: 600;
                }
                .task-list-item {
                    list-style-type: none;
                    margin-left: -1.5em;
                }
                .task-list-item input {
                    margin-right: 0.5em;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
    }
    
    private func markdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // Escape HTML entities first
        html = html.replacingOccurrences(of: "&", with: "&amp;")
        html = html.replacingOccurrences(of: "<", with: "&lt;")
        html = html.replacingOccurrences(of: ">", with: "&gt;")
        
        // Code blocks (must be before inline code)
        let codeBlockPattern = "```([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            html = regex.stringByReplacingMatches(in: html, options: [], range: NSRange(html.startIndex..., in: html), withTemplate: "<pre><code>$1</code></pre>")
        }
        
        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Headers
        html = html.replacingOccurrences(of: "(?m)^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        
        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: "__(.+?)__", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)
        
        // Strikethrough
        html = html.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)
        
        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        
        // Images
        html = html.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        
        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\*\\*\\*+$", with: "<hr>", options: .regularExpression)
        
        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^> (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // Task lists
        html = html.replacingOccurrences(of: "(?m)^- \\[x\\] (.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> $1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^- \\[ \\] (.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> $1</li>", options: .regularExpression)
        
        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^- (.+)$", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\* (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Wrap consecutive <li> tags in <ul>
        let liPattern = "(<li>.*?</li>\\s*)+"
        if let regex = try? NSRegularExpression(pattern: liPattern, options: []) {
            html = regex.stringByReplacingMatches(in: html, options: [], range: NSRange(html.startIndex..., in: html), withTemplate: "<ul>$0</ul>")
        }
        
        // Paragraphs - wrap remaining text blocks
        let lines = html.components(separatedBy: "\n\n")
        html = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<ul") || trimmed.hasPrefix("<ol") ||
               trimmed.hasPrefix("<pre") || trimmed.hasPrefix("<blockquote") || trimmed.hasPrefix("<hr") {
                return trimmed
            }
            return "<p>\(trimmed)</p>"
        }.joined(separator: "\n")
        
        // Clean up line breaks within paragraphs
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        html = html.replacingOccurrences(of: "<br><br>", with: "</p><p>")
        
        return html
    }
}

#Preview {
    MarkdownPreviewView(
        markdown: """
        # Hello World
        
        This is **bold** and *italic* text.
        
        ## Features
        - Item 1
        - Item 2
        
        ```swift
        let x = 42
        ```
        """,
        isDarkMode: .constant(false)
    )
}
