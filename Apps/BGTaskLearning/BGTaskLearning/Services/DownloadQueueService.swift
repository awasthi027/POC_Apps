import Foundation
import SwiftData

@Observable
final class DownloadQueueService {
    private(set) var queue: [FileDownload] = []
    private let dataStore: DataStore
    private var isProcessing = false
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    func enqueueDownload(_ fileDownload: FileDownload) throws {
        queue.append(fileDownload)
        try dataStore.updateFileDownloadStatus(fileDownload, status: .pending)
        print("Download queued: \(fileDownload.fileName)")
    }
    
    func processQueue() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        
        let downloadToProcess = queue.removeFirst()
        print("Processing download from queue: \(downloadToProcess.fileName)")
        
        FileDownloadManager.shared.startDownload(downloadToProcess)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isProcessing = false
            if let queue = self?.queue, !queue.isEmpty {
                self?.processQueue()
            }
        }
    }
    
    func startQueueProcessing() {
        // Load pending downloads from database into queue
        // EXCLUDES downloads from APNS (isFromAPNS=true) - they start immediately
        do {
            let pendingDownloads = try dataStore.fetchPendingDownloads()
            queue = pendingDownloads.filter { !$0.isFromAPNS }
            print("Loaded \(queue.count) pending downloads from database (APNS downloads excluded)")
            processQueue()
        } catch {
            print("Error loading pending downloads: \(error)")
        }
    }
    
    func getQueuedDownloads() throws -> [FileDownload] {
        return try dataStore.fetchPendingDownloads()
    }
    
    func clearQueue() {
        queue.removeAll()
    }
}
