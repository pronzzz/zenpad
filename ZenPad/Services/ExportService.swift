import Foundation
import AppKit
import PDFKit
import WebKit

// MARK: - Export Service

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - PDF Export
    
    func exportToPDF(_ document: Document, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(document.title).pdf"
        panel.message = "Export as PDF"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            completion(nil)
            return
        }
        
        // Generate PDF
        let pdfData = generatePDF(for: document)
        
        do {
            try pdfData.write(to: url)
            completion(url)
        } catch {
            print("PDF export failed: \(error)")
            completion(nil)
        }
    }
    
    private func generatePDF(for document: Document) -> Data {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }
        
        // Create attributed string
        let font = NSFont.systemFont(ofSize: 12)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: document.content, attributes: attributes)
        
        // Calculate text layout
        let textRect = pageRect.insetBy(dx: 72, dy: 72)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        var currentRange = CFRange(location: 0, length: 0)
        var currentPage = 0
        
        while currentRange.location < attributedString.length {
            context.beginPDFPage(nil)
            
            // Draw title on first page
            if currentPage == 0 {
                let titleFont = NSFont.boldSystemFont(ofSize: 18)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: NSColor.black
                ]
                let titleString = NSAttributedString(string: document.title, attributes: titleAttributes)
                let titleLine = CTLineCreateWithAttributedString(titleString)
                
                context.textPosition = CGPoint(x: 72, y: pageRect.height - 72)
                CTLineDraw(titleLine, context)
            }
            
            // Create path for text
            let path = CGPath(rect: textRect.offsetBy(dx: 0, dy: currentPage == 0 ? -30 : 0), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            
            // Draw frame
            context.saveGState()
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
            CTFrameDraw(frame, context)
            context.restoreGState()
            
            // Get visible range
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange = CFRange(location: visibleRange.location + visibleRange.length, length: 0)
            
            context.endPDFPage()
            currentPage += 1
            
            // Safety limit
            if currentPage > 1000 { break }
        }
        
        context.closePDF()
        
        return pdfData as Data
    }
    
    // MARK: - HTML Export
    
    func exportToHTML(_ document: Document, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(document.title).html"
        panel.message = "Export as HTML"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            completion(nil)
            return
        }
        
        let html = generateHTML(for: document)
        
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            completion(url)
        } catch {
            print("HTML export failed: \(error)")
            completion(nil)
        }
    }
    
    private func generateHTML(for document: Document) -> String {
        // Convert content based on file type
        let contentHTML: String
        if document.fileType == .markdown {
            contentHTML = markdownToHTML(document.content)
        } else {
            contentHTML = "<pre>\(document.content.htmlEscaped)</pre>"
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(document.title.htmlEscaped)</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                    line-height: 1.7;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 40px 20px;
                    color: #1a1a1a;
                    background: #fff;
                }
                h1 { font-size: 2.5em; margin-bottom: 0.5em; border-bottom: 2px solid #eee; padding-bottom: 0.3em; }
                h2 { font-size: 1.8em; margin-top: 1.5em; }
                h3 { font-size: 1.4em; }
                p { margin: 1em 0; }
                pre {
                    background: #f6f8fa;
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 0.9em;
                }
                code {
                    background: #f6f8fa;
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 0.9em;
                }
                pre code { background: none; padding: 0; }
                blockquote {
                    border-left: 4px solid #ddd;
                    margin: 1em 0;
                    padding-left: 1em;
                    color: #666;
                }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
                ul, ol { padding-left: 2em; }
                hr { border: none; border-top: 1px solid #eee; margin: 2em 0; }
                img { max-width: 100%; height: auto; border-radius: 8px; }
                .meta {
                    color: #666;
                    font-size: 0.9em;
                    margin-bottom: 2em;
                }
                @media (prefers-color-scheme: dark) {
                    body { background: #1a1a1a; color: #e0e0e0; }
                    pre, code { background: #2d2d2d; }
                    h1 { border-bottom-color: #333; }
                    blockquote { border-left-color: #444; color: #999; }
                    hr { border-top-color: #333; }
                }
            </style>
        </head>
        <body>
            <h1>\(document.title.htmlEscaped)</h1>
            <div class="meta">
                Created: \(document.createdAt.formatted()) • 
                Modified: \(document.modifiedAt.formatted())
            </div>
            \(contentHTML)
            <footer style="margin-top: 3em; padding-top: 1em; border-top: 1px solid #eee; color: #999; font-size: 0.85em;">
                Exported from ZenPad
            </footer>
        </body>
        </html>
        """
    }
    
    private func markdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // Headers
        html = html.replacingOccurrences(of: "(?m)^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        
        // Bold & Italic
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // Code blocks
        html = html.replacingOccurrences(of: "```([\\s\\S]*?)```", with: "<pre><code>$1</code></pre>", options: .regularExpression)
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        
        // Lists
        html = html.replacingOccurrences(of: "(?m)^- (.+)$", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        return html
    }
    
    // MARK: - Print
    
    func printDocument(_ document: Document) {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
        textView.string = document.content
        textView.font = NSFont.systemFont(ofSize: 12)
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}

// MARK: - GitHub Gist Service

class GistService {
    static let shared = GistService()
    
    private var token: String? {
        get { UserDefaults.standard.string(forKey: "githubToken") }
        set { UserDefaults.standard.set(newValue, forKey: "githubToken") }
    }
    
    var isAuthenticated: Bool { token != nil }
    
    private init() {}
    
    func setToken(_ token: String) {
        self.token = token
    }
    
    func clearToken() {
        self.token = nil
    }
    
    func createGist(from document: Document, isPublic: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = token else {
            completion(.failure(GistError.notAuthenticated))
            return
        }
        
        let url = URL(string: "https://api.github.com/gists")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let filename = "\(document.title).\(document.fileType.rawValue)"
        let payload: [String: Any] = [
            "description": "Created with ZenPad",
            "public": isPublic,
            "files": [
                filename: [
                    "content": document.content
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let htmlURL = json["html_url"] as? String else {
                completion(.failure(GistError.invalidResponse))
                return
            }
            
            completion(.success(htmlURL))
        }.resume()
    }
    
    enum GistError: Error, LocalizedError {
        case notAuthenticated
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please add your GitHub token in preferences."
            case .invalidResponse:
                return "Failed to create Gist. Please try again."
            }
        }
    }
}

// MARK: - String Extension

private extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
