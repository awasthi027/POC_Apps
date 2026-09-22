import Foundation
import SwiftData
import UserNotifications

final class FileDownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = FileDownloadManager()
    
    private var session: URLSession?
    private var downloads: [String: URLSessionDownloadTask] = [:]
    private var fileDownloadMap: [URLSessionDownloadTask: String] = [:]
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var dataStoreProvider: (() -> DataStore?)?
    
    override init() {
        super.init()
        setupURLSession()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.bgtasklearning.downloads")
        config.waitsForConnectivity = true
        config.isDiscretionary = false
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startDownload(_ fileDownload: FileDownload) {
        guard let session = session else { return }
        
        let request = URLRequest(url: URL(string: fileDownload.url)!)
        
        if let resumeData = fileDownload.resumeData {
            let task = session.downloadTask(withResumeData: resumeData)
            downloads[fileDownload.id] = task
            fileDownloadMap[task] = fileDownload.id
            task.resume()
        } else {
            let task = session.downloadTask(with: request)
            downloads[fileDownload.id] = task
            fileDownloadMap[task] = fileDownload.id
            task.resume()
        }
        
        try? dataStoreProvider?()?.updateFileDownloadStatus(fileDownload, status: .downloading)
        
        if #available(iOS 16.1, *) {
            DownloadActivityManager.shared.startActivity(
                downloadId: fileDownload.id,
                fileName: fileDownload.fileName,
                totalSize: fileDownload.fileSize
            )
        }
    }
    
    func pauseDownload(_ fileDownload: FileDownload) {
        guard let task = downloads[fileDownload.id] else { return }
        
        task.cancel(byProducingResumeData: { [weak self] resumeData in
            guard let self = self, let dataStore = self.dataStoreProvider?() else { return }
            try? dataStore.updateFileDownloadResumeData(fileDownload, resumeData: resumeData)
            try? dataStore.updateFileDownloadStatus(fileDownload, status: .paused)
        })
    }
    
    func cancelDownload(_ fileDownload: FileDownload) {
        downloads[fileDownload.id]?.cancel()
        if let task = downloads[fileDownload.id] {
            fileDownloadMap.removeValue(forKey: task)
        }
        downloads.removeValue(forKey: fileDownload.id)
        try? dataStoreProvider?()?.updateFileDownloadStatus(fileDownload, status: .cancelled)
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let fileDownloadId = fileDownloadMap[downloadTask],
              let dataStore = dataStoreProvider?() else {
            try? FileManager.default.removeItem(at: location)
            return
        }
        
        // IMPORTANT: The temp file at `location` is only valid for the duration
        // of this delegate call and is deleted immediately after it returns.
        // We must move it synchronously here, NOT inside an async dispatch block.
        var moveError: Error?
        var destinationPath: String?
        
        do {
            let downloads = try dataStore.fetchAllFileDownloads()
            if let fileDownload = downloads.first(where: { $0.id == fileDownloadId }) {
                let destinationURL = documentsPath.appendingPathComponent(fileDownload.fileName)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)
                destinationPath = destinationURL.path
            }
        } catch {
            moveError = error
            try? FileManager.default.removeItem(at: location)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let downloads = try dataStore.fetchAllFileDownloads()
                guard let fileDownload = downloads.first(where: { $0.id == fileDownloadId }) else { return }
                
                let fileName = fileDownload.fileName
                
                if let destinationPath = destinationPath {
                    try dataStore.completeFileDownload(fileDownload, localPath: destinationPath)
                    // Only send notification if enabled for this download
                    if fileDownload.isLocalNotificationEnabled {
                        self.sendDownloadNotification(fileName: fileName, success: true, error: nil)
                    }
                    print("Download completed: \(fileName)")
                    
                    if #available(iOS 16.1, *) {
                        DownloadActivityManager.shared.endActivity(downloadId: fileDownloadId, fileName: fileName, success: true)
                    }
                } else {
                    let errorMessage = moveError?.localizedDescription ?? "Unknown error moving file"
                    try dataStore.failFileDownload(fileDownload, error: errorMessage)
                    // Only send notification if enabled for this download
                    if fileDownload.isLocalNotificationEnabled {
                        self.sendDownloadNotification(fileName: fileName, success: false, error: errorMessage)
                    }
                    print("Download failed: \(fileName) - \(errorMessage)")
                    
                    if #available(iOS 16.1, *) {
                        DownloadActivityManager.shared.endActivity(downloadId: fileDownloadId, fileName: fileName, success: false)
                    }
                }
            } catch {
                print("Error handling download completion: \(error)")
            }
            
            self.downloads.removeValue(forKey: fileDownloadId)
            self.fileDownloadMap.removeValue(forKey: downloadTask)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let fileDownloadId = fileDownloadMap[downloadTask],
              let dataStore = dataStoreProvider?() else { return }
        
        DispatchQueue.main.async {
            do {
                let downloads = try dataStore.fetchAllFileDownloads()
                guard let fileDownload = downloads.first(where: { $0.id == fileDownloadId }) else { return }
                try dataStore.updateFileDownloadProgress(fileDownload, downloadedSize: totalBytesWritten, totalSize: totalBytesExpectedToWrite)
                
                if #available(iOS 16.1, *) {
                    DownloadActivityManager.shared.updateActivity(
                        downloadId: fileDownloadId,
                        fileName: fileDownload.fileName,
                        downloadedSize: totalBytesWritten,
                        totalSize: totalBytesExpectedToWrite
                    )
                }
            } catch {
                print("Error updating download progress: \(error)")
            }
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let fileDownloadId = fileDownloadMap[downloadTask],
              let dataStore = dataStoreProvider?() else { return }
        
        if let error = error {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    do {
                        let downloads = try dataStore.fetchAllFileDownloads()
                        guard let fileDownload = downloads.first(where: { $0.id == fileDownloadId }) else { return }
                        try dataStore.failFileDownload(fileDownload, error: error.localizedDescription)
                        
                        // Only send notification if enabled for this download
                        if fileDownload.isLocalNotificationEnabled {
                            self.sendDownloadNotification(fileName: fileDownload.fileName, success: false, error: error.localizedDescription)
                        }
                        print("Download error for \(fileDownload.fileName): \(error.localizedDescription)")
                        
                        if #available(iOS 16.1, *) {
                            DownloadActivityManager.shared.endActivity(downloadId: fileDownloadId, fileName: fileDownload.fileName, success: false)
                        }
                    } catch {
                        print("Error handling download error: \(error)")
                    }
                    
                    self.fileDownloadMap.removeValue(forKey: downloadTask)
                    self.downloads.removeValue(forKey: fileDownloadId)
                }
            }
        }
    }
    
    func resumeAllPausedDownloads(dataStore: DataStore) {
        do {
            let pausedDownloads = try dataStore.fetchPausedDownloads()
            for fileDownload in pausedDownloads {
                startDownload(fileDownload)
            }
        } catch {
            print("Error resuming downloads: \(error)")
        }
    }
    
    private func sendDownloadNotification(fileName: String, success: Bool, error: String?) {
        let content = UNMutableNotificationContent()
        
        if success {
            content.title = "✅ Download Complete"
            content.body = "\(fileName) has finished downloading successfully"
        } else {
            content.title = "❌ Download Failed"
            content.body = "\(fileName) failed to download\n\(error ?? "Unknown error")"
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }
    }
}
