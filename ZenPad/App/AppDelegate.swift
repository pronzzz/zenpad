import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var servicesProvider: ServicesProvider?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app appearance
        NSApp.appearance = nil // Follow system appearance
        
        // Setup auto-save timer
        AutoSaveService.shared.startAutoSave()
        
        // Setup menu bar quick note
        MenuBarController.shared.setupMenuBar()
        
        // Register global hotkey (Ctrl+Shift+N)
        GlobalHotkeyManager.shared.registerGlobalHotkey()
        
        // Setup Services menu
        setupServicesMenu()
        
        // Check AI service connection
        Task {
            await AIService.shared.checkConnection()
        }
        
        // Initial iCloud sync if enabled
        if CloudSyncService.shared.isEnabled {
            CloudSyncService.shared.syncAllDocuments()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop auto-save
        AutoSaveService.shared.stopAutoSave()
        
        // Unregister global hotkey
        GlobalHotkeyManager.shared.unregisterGlobalHotkey()
        
        // Stop Handoff activity
        HandoffManager.shared.stopActivity()
        
        // Final iCloud sync
        if CloudSyncService.shared.isEnabled {
            CloudSyncService.shared.syncAllDocuments()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running for menu bar
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check for unsaved documents
        if DocumentManager.shared.hasUnsavedDocuments {
            let alert = NSAlert()
            alert.messageText = "You have unsaved changes"
            alert.informativeText = "Do you want to save your changes before quitting?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save All")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                DocumentManager.shared.saveAllDocuments()
                return .terminateNow
            case .alertSecondButtonReturn:
                return .terminateNow
            default:
                return .terminateCancel
            }
        }
        return .terminateNow
    }
    
    // MARK: - Handoff Support
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        return HandoffManager.shared.handleUserActivity(userActivity)
    }
    
    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return userActivityType == "com.zenpad.editing"
    }
    
    // MARK: - Services Menu
    
    private func setupServicesMenu() {
        servicesProvider = ServicesProvider()
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()
    }
    
    // MARK: - Open Files
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            DocumentManager.shared.openDocument(at: url)
        }
    }
    
    // MARK: - Dock Menu
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        menu.addItem(withTitle: "New Document", action: #selector(newDocument), keyEquivalent: "")
        menu.addItem(withTitle: "Quick Note", action: #selector(showQuickNote), keyEquivalent: "")
        
        // Recent documents
        let recentDocs = DocumentManager.shared.documents.prefix(5)
        if !recentDocs.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let headerItem = menu.addItem(withTitle: "Recent Documents", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            
            for doc in recentDocs {
                let item = NSMenuItem(title: doc.title, action: #selector(openRecentDocument(_:)), keyEquivalent: "")
                item.representedObject = doc.id
                menu.addItem(item)
            }
        }
        
        return menu
    }
    
    @objc private func newDocument() {
        NSApp.activate(ignoringOtherApps: true)
        DocumentManager.shared.createNewDocument()
    }
    
    @objc private func showQuickNote() {
        MenuBarController.shared.showPopover()
    }
    
    @objc private func openRecentDocument(_ sender: NSMenuItem) {
        guard let docId = sender.representedObject as? UUID else { return }
        NSApp.activate(ignoringOtherApps: true)
        DocumentManager.shared.currentDocumentId = docId
    }
}
