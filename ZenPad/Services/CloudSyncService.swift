import Foundation
import CloudKit

// MARK: - iCloud Sync Service

class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    
    @Published var isEnabled = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let fileManager = FileManager.default
    private let containerIdentifier = "iCloud.com.zenpad.documents"
    
    private var iCloudURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
    
    var isCloudAvailable: Bool {
        fileManager.ubiquityIdentityToken != nil
    }
    
    private init() {
        checkCloudStatus()
        setupNotifications()
    }
    
    // MARK: - Status Check
    
    private func checkCloudStatus() {
        isEnabled = isCloudAvailable && UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        if isEnabled {
            createCloudDirectory()
        }
    }
    
    private func createCloudDirectory() {
        guard let url = iCloudURL else { return }
        
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquityIdentityDidChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
    }
    
    @objc private func ubiquityIdentityDidChange() {
        checkCloudStatus()
    }
    
    // MARK: - Enable/Disable
    
    func enableSync() {
        guard isCloudAvailable else {
            syncError = "iCloud is not available. Please sign in to iCloud in System Preferences."
            return
        }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        createCloudDirectory()
        syncAllDocuments()
    }
    
    func disableSync() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
    }
    
    // MARK: - Sync Operations
    
    func syncAllDocuments() {
        guard isEnabled, let cloudURL = iCloudURL else { return }
        
        Task { @MainActor in
            isSyncing = true
            syncError = nil
        }
        
        Task {
            do {
                // Get local documents
                let localDocuments = DocumentManager.shared.documents.filter { $0.filePath != nil }
                
                for document in localDocuments {
                    try await syncDocument(document, to: cloudURL)
                }
                
                // Check for cloud-only documents
                try await fetchCloudDocuments(from: cloudURL)
                
                await MainActor.run {
                    isSyncing = false
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncError = error.localizedDescription
                }
            }
        }
    }
    
    private func syncDocument(_ document: Document, to cloudURL: URL) async throws {
        guard let localPath = document.filePath else { return }
        
        let cloudPath = cloudURL.appendingPathComponent(localPath.lastPathComponent)
        
        // Check if cloud version is newer
        if fileManager.fileExists(atPath: cloudPath.path) {
            let cloudAttributes = try fileManager.attributesOfItem(atPath: cloudPath.path)
            let localAttributes = try fileManager.attributesOfItem(atPath: localPath.path)
            
            let cloudDate = cloudAttributes[.modificationDate] as? Date ?? .distantPast
            let localDate = localAttributes[.modificationDate] as? Date ?? .distantPast
            
            if cloudDate > localDate {
                // Cloud is newer, download
                try fileManager.removeItem(at: localPath)
                try fileManager.copyItem(at: cloudPath, to: localPath)
            } else if localDate > cloudDate {
                // Local is newer, upload
                try fileManager.removeItem(at: cloudPath)
                try fileManager.copyItem(at: localPath, to: cloudPath)
            }
        } else {
            // Upload to cloud
            try fileManager.copyItem(at: localPath, to: cloudPath)
        }
    }
    
    private func fetchCloudDocuments(from cloudURL: URL) async throws {
        let cloudFiles = try fileManager.contentsOfDirectory(at: cloudURL, includingPropertiesForKeys: [.contentModificationDateKey])
        
        for cloudFile in cloudFiles {
            let localDocsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let localPath = localDocsPath.appendingPathComponent(cloudFile.lastPathComponent)
            
            if !fileManager.fileExists(atPath: localPath.path) {
                // Download from cloud
                try fileManager.copyItem(at: cloudFile, to: localPath)
                
                // Open in app
                await MainActor.run {
                    DocumentManager.shared.openDocument(at: localPath)
                }
            }
        }
    }
    
    func syncDocument(_ document: Document) {
        guard isEnabled, let cloudURL = iCloudURL else { return }
        
        Task {
            do {
                try await syncDocument(document, to: cloudURL)
                
                await MainActor.run {
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Cloud Settings View

import SwiftUI

struct CloudSettingsView: View {
    @ObservedObject private var cloudService = CloudSyncService.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: cloudService.isCloudAvailable ? "checkmark.icloud" : "xmark.icloud")
                        .foregroundColor(cloudService.isCloudAvailable ? .green : .red)
                    Text(cloudService.isCloudAvailable ? "iCloud Available" : "iCloud Unavailable")
                }
                
                Toggle("Enable iCloud Sync", isOn: Binding(
                    get: { cloudService.isEnabled },
                    set: { newValue in
                        if newValue {
                            cloudService.enableSync()
                        } else {
                            cloudService.disableSync()
                        }
                    }
                ))
                .disabled(!cloudService.isCloudAvailable)
                
                if cloudService.isEnabled {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        if let date = cloudService.lastSyncDate {
                            Text(date, style: .relative)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sync Now") {
                        cloudService.syncAllDocuments()
                    }
                    .disabled(cloudService.isSyncing)
                }
                
                if let error = cloudService.syncError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section("About") {
                Text("Documents saved to iCloud are available on all your devices signed into the same Apple ID.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
