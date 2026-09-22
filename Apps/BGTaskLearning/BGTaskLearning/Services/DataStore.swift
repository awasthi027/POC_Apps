import Foundation
import SwiftData

@Observable
final class DataStore {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - FileDownload Operations
    
    func createFileDownload(url: String, fileName: String, fileSize: Int64 = 0,
                            isFromAPNS: Bool = false,
                            isLocalNotificationEnabled: Bool = false) throws -> FileDownload {
        let newDownload = FileDownload(
            url: url,
            fileName: fileName,
            fileSize: fileSize,
            status: .pending,
            isLocalNotificationEnabled: isLocalNotificationEnabled,
            isFromAPNS: isFromAPNS
        )
        modelContext.insert(newDownload)
        try modelContext.save()
        return newDownload
    }
    
    /// Create a download from APNS notification
    /// - Marked as isFromAPNS=true so it won't be re-queued when app goes to background
    /// - Status set to .downloading so it starts immediately
    func createFileDownloadFromAPNS(url: String, fileName: String, fileSize: Int64 = 0) throws -> FileDownload {
        let newDownload = FileDownload(
            url: url,
            fileName: fileName,
            fileSize: fileSize,
            status: .downloading,
            isFromAPNS: true
        )
        modelContext.insert(newDownload)
        try modelContext.save()
        return newDownload
    }
    
    func fetchAllFileDownloads() throws -> [FileDownload] {
        let descriptor = FetchDescriptor<FileDownload>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func updateFileDownloadStatus(_ download: FileDownload, status: DownloadStatus) throws {
        download.status = status
        download.updatedAt = Date()
        try modelContext.save()
    }
    
    func updateFileDownloadProgress(_ download: FileDownload, downloadedSize: Int64, totalSize: Int64) throws {
        download.downloadedSize = downloadedSize
        download.fileSize = totalSize
        download.updatedAt = Date()
        try modelContext.save()
    }
    
    func updateFileDownloadResumeData(_ download: FileDownload, resumeData: Data?) throws {
        download.resumeData = resumeData
        download.updatedAt = Date()
        try modelContext.save()
    }
    
    func completeFileDownload(_ download: FileDownload, localPath: String) throws {
        download.localPath = localPath
        download.status = .completed
        download.downloadedSize = download.fileSize
        download.resumeData = nil
        download.error = nil
        download.updatedAt = Date()
        try modelContext.save()
    }
    
    func failFileDownload(_ download: FileDownload, error: String) throws {
        download.status = .failed
        download.error = error
        download.updatedAt = Date()
        try modelContext.save()
    }
    
    func deleteFileDownload(_ download: FileDownload) throws {
        modelContext.delete(download)
        try modelContext.save()
    }
    
    func fetchPausedDownloads() throws -> [FileDownload] {
        let descriptor = FetchDescriptor<FileDownload>()
        let allDownloads = try modelContext.fetch(descriptor)
        return allDownloads.filter { $0.status == .paused }
    }
    
    func fetchPendingDownloads() throws -> [FileDownload] {
        let descriptor = FetchDescriptor<FileDownload>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let allDownloads = try modelContext.fetch(descriptor)
        return allDownloads.filter { $0.status == .pending }
    }
    
    // MARK: - Item Operations
    
    func createItem(timestamp: Date = Date()) throws -> Item {
        let newItem = Item(timestamp: timestamp)
        modelContext.insert(newItem)
        try modelContext.save()
        return newItem
    }
    
    func fetchAllItems() throws -> [Item] {
        let descriptor = FetchDescriptor<Item>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func deleteItem(_ item: Item) throws {
        modelContext.delete(item)
        try modelContext.save()
    }
}
