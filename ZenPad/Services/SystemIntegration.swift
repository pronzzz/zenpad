import Foundation
import AppKit
import Carbon.HIToolbox

// MARK: - Global Hotkey Manager

class GlobalHotkeyManager: NSObject {
    static let shared = GlobalHotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Register Hotkey
    
    func registerGlobalHotkey() {
        // Default: Ctrl+Shift+N for Quick Note
        let modifiers: UInt32 = UInt32(controlKey | shiftKey)
        let keyCode: UInt32 = 45 // 'N' key
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install event handler
        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                GlobalHotkeyManager.shared.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        guard handlerResult == noErr else {
            print("Failed to install event handler: \(handlerResult)")
            return
        }
        
        // Register hotkey
        var hotKeyID = EventHotKeyID(signature: OSType(0x5A504144), id: 1) // "ZPAD"
        
        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerResult != noErr {
            print("Failed to register hotkey: \(registerResult)")
        }
    }
    
    func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func handleHotkey() {
        DispatchQueue.main.async {
            MenuBarController.shared.showPopover()
        }
    }
}

// MARK: - Handoff Support

class HandoffManager: NSObject, NSUserActivityDelegate {
    static let shared = HandoffManager()
    
    private let activityType = "com.zenpad.editing"
    private var currentActivity: NSUserActivity?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Start Activity
    
    func startActivity(for document: Document) {
        // End previous activity
        currentActivity?.invalidate()
        
        // Create new activity
        let activity = NSUserActivity(activityType: activityType)
        activity.title = "Editing \(document.title)"
        activity.isEligibleForHandoff = true
        activity.needsSave = true
        activity.delegate = self
        
        // Add document info
        activity.userInfo = [
            "documentId": document.id.uuidString,
            "documentTitle": document.title,
            "documentContent": document.content.prefix(1000).description
        ]
        
        // Add keywords for search
        activity.keywords = Set([document.title, "ZenPad", "note", "text"])
        
        // Set file URL if available
        if let filePath = document.filePath {
            activity.userInfo?["filePath"] = filePath.path
        }
        
        activity.becomeCurrent()
        currentActivity = activity
    }
    
    func stopActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }
    
    // MARK: - Handle Incoming Handoff
    
    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == activityType else { return false }
        
        if let filePath = userActivity.userInfo?["filePath"] as? String {
            let url = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: filePath) {
                DocumentManager.shared.openDocument(at: url)
                return true
            }
        }
        
        // Fallback: create new document with content
        if let content = userActivity.userInfo?["documentContent"] as? String,
           let title = userActivity.userInfo?["documentTitle"] as? String {
            DocumentManager.shared.createNewDocument()
            if let docId = DocumentManager.shared.currentDocumentId {
                DocumentManager.shared.updateContent(content, for: docId)
            }
            return true
        }
        
        return false
    }
    
    // MARK: - NSUserActivityDelegate
    
    func userActivityWillSave(_ userActivity: NSUserActivity) {
        // Update content before saving
        if let doc = DocumentManager.shared.currentDocument {
            userActivity.userInfo?["documentContent"] = doc.content.prefix(1000).description
        }
    }
}

// MARK: - Quick Look Preview Extension Support

class QuickLookGenerator {
    static func generatePreview(for url: URL) -> Data? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        // Generate HTML preview
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                }
                pre {
                    background: #f5f5f5;
                    padding: 10px;
                    border-radius: 4px;
                    overflow-x: auto;
                }
                code {
                    font-family: 'SF Mono', Menlo, monospace;
                }
            </style>
        </head>
        <body>
            <pre><code>\(content.htmlEscaped)</code></pre>
        </body>
        </html>
        """
        
        return html.data(using: .utf8)
    }
}

// MARK: - Services Menu Support

class ServicesProvider: NSObject {
    @objc func openInZenPad(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            return
        }
        
        // Create new document with text
        DocumentManager.shared.createNewDocument()
        if let docId = DocumentManager.shared.currentDocumentId {
            DocumentManager.shared.updateContent(text, for: docId)
        }
        
        // Activate app
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func newQuickNote(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        // Show quick note popover with selected text
        if let text = pasteboard.string(forType: .string) {
            MenuBarController.shared.quickNoteText = text
        }
        MenuBarController.shared.showPopover()
    }
}

// MARK: - String Extension

private extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
