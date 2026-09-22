import Foundation
import UIKit
import SwiftData
import Observation
import UserNotifications

@Observable
final class DownloadsViewModel {
    var availableFiles: [DownloadableFile] = []
    var downloadedFiles: [FileDownload] = []
    var activeDownloads: [FileDownload] = []
    var isLoading = false
    var errorMessage: String?
    
    private var dataStore: DataStore?
    private var downloadQueue: DownloadQueueService?
    private let downloadManager = FileDownloadManager.shared
    
    init() {
        self.availableFiles = DownloadableFilesService.shared.getAllFiles()
    }
    
    func setup(modelContext: ModelContext) {
        let dataStore = DataStore(modelContext: modelContext)
        self.dataStore = dataStore
        self.downloadQueue = DownloadQueueService(dataStore: dataStore)
        
        downloadManager.dataStoreProvider = { dataStore }
        
        refreshDownloads()
    }
    
    func refreshDownloads() {
        guard let dataStore else { return }
        
        do {
            let allDownloads = try dataStore.fetchAllFileDownloads()
            downloadedFiles = allDownloads.filter { $0.status == .completed }
            activeDownloads = allDownloads.filter { $0.status == .downloading || $0.status == .pending }
        } catch {
            errorMessage = "Failed to load downloads: \(error.localizedDescription)"
        }
    }

    func initiateDownload(_ file: DownloadableFile) {
        guard let dataStore, let downloadQueue else { return }
        
        do {
            // Check if already downloaded
            let existingDownloads = try dataStore.fetchAllFileDownloads()
            if existingDownloads.contains(where: { $0.url == file.url && $0.status == .completed }) {
                errorMessage = "File already downloaded"
                return
            }
            
            // Create download entry
            let newDownload = try dataStore.createFileDownload(
                url: file.url,
                fileName: file.name,
                fileSize: file.fileSize,
                isLocalNotificationEnabled: true
            )
            
            // Start the Live Activity now, while the app is still in the
            // foreground. ActivityKit does NOT allow starting a new Live
            // Activity once the app is backgrounded — only updating/ending
            // an already-running one is allowed from the background.
            if #available(iOS 16.1, *) {
                DownloadActivityManager.shared.startActivity(
                    downloadId: newDownload.id,
                    fileName: newDownload.fileName,
                    totalSize: newDownload.fileSize
                )
            }
            
            // Queue the download
            try downloadQueue.enqueueDownload(newDownload)
            
            refreshDownloads()
        } catch {
            errorMessage = "Failed to initiate download: \(error.localizedDescription)"
        }
    }
    
    func startDownloadsFromQueue() {
        downloadQueue?.startQueueProcessing()
    }
    
    func deleteDownload(_ download: FileDownload) {
        guard let dataStore else { return }
        
        if download.status == .downloading {
            downloadManager.cancelDownload(download)
        }
        
        if let localPath = download.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }
        
        do {
            try dataStore.deleteFileDownload(download)
            refreshDownloads()
        } catch {
            errorMessage = "Failed to delete download: \(error.localizedDescription)"
        }
    }
    
    func getDownloadProgress(_ download: FileDownload) -> Double {
        guard download.fileSize > 0 else { return 0 }
        return Double(download.downloadedSize) / Double(download.fileSize)
    }
    
    func getDownloadProgressPercentage(_ download: FileDownload) -> String {
        let progress = getDownloadProgress(download)
        return String(format: "%.1f%%", progress * 100)
    }
    
    func getFormattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func sendDownloadCompleteNotification(_ download: FileDownload) {
        // Only send if notification is enabled for this download
        guard download.isLocalNotificationEnabled else { return }
         
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\(download.fileName) is ready"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
         
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllDownloadedFiles() {
        guard let dataStore else { return }
        
        do {
            let allDownloads = try dataStore.fetchAllFileDownloads()
            for download in allDownloads where download.status == .completed {
                if let localPath = download.localPath {
                    try? FileManager.default.removeItem(atPath: localPath)
                }
                try dataStore.deleteFileDownload(download)
            }
            refreshDownloads()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to clear files: \(error.localizedDescription)"
        }
    }
}
