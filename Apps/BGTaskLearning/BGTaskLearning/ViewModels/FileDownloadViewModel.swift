import Foundation
import SwiftData
import Observation

@Observable
final class FileDownloadViewModel {
    var fileDownloads: [FileDownload] = []
    var selectedDownload: FileDownload?
    var isLoading = false
    var errorMessage: String?
    
    private var dataStore: DataStore?
    private let downloadManager = FileDownloadManager.shared
    
    init(dataStore: DataStore? = nil) {
        self.dataStore = dataStore
        setupDownloadManager()
    }
    
    func setDataStore(_ dataStore: DataStore) {
        self.dataStore = dataStore
        setupDownloadManager()
        loadDownloads()
    }
    
    private func setupDownloadManager() {
        downloadManager.dataStoreProvider = { [weak self] in
            self?.dataStore
        }
    }
    
    func loadDownloads() {
        guard let dataStore else { return }
        
        do {
            fileDownloads = try dataStore.fetchAllFileDownloads()
        } catch {
            errorMessage = "Failed to load downloads: \(error.localizedDescription)"
        }
    }
    
    func createDownload(url: String, fileName: String, fileSize: Int64 = 0) {
        guard let dataStore else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let newDownload = try dataStore.createFileDownload(url: url,
                                                               fileName: fileName,
                                                               fileSize: fileSize)
            fileDownloads.append(newDownload)
            startDownload(newDownload)
        } catch {
            errorMessage = "Failed to create download: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func startDownload(_ fileDownload: FileDownload) {
        guard let dataStore else { return }
        downloadManager.dataStoreProvider = { dataStore }
        downloadManager.startDownload(fileDownload)
    }
    
    func pauseDownload(_ fileDownload: FileDownload) {
        downloadManager.pauseDownload(fileDownload)
    }
    
    func resumeDownload(_ fileDownload: FileDownload) {
        guard let dataStore else { return }
        downloadManager.dataStoreProvider = { dataStore }
        downloadManager.startDownload(fileDownload)
    }
    
    func cancelDownload(_ fileDownload: FileDownload) {
        downloadManager.cancelDownload(fileDownload)
    }
    
    func deleteDownload(_ fileDownload: FileDownload) {
        guard let dataStore else { return }
        
        if fileDownload.status == .downloading {
            cancelDownload(fileDownload)
        }
        
        if let localPath = fileDownload.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }
        
        do {
            try dataStore.deleteFileDownload(fileDownload)
            fileDownloads.removeAll { $0.id == fileDownload.id }
        } catch {
            errorMessage = "Failed to delete download: \(error.localizedDescription)"
        }
    }
    
    func getDownloadProgress(_ fileDownload: FileDownload) -> Double {
        guard fileDownload.fileSize > 0 else { return 0 }
        return Double(fileDownload.downloadedSize) / Double(fileDownload.fileSize)
    }
    
    func getDownloadProgressPercentage(_ fileDownload: FileDownload) -> String {
        let progress = getDownloadProgress(fileDownload)
        return String(format: "%.1f%%", progress * 100)
    }
    
    func getFormattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func resumeAllPausedDownloads() {
        guard let dataStore else { return }
        downloadManager.dataStoreProvider = { dataStore }
        downloadManager.resumeAllPausedDownloads(dataStore: dataStore)
        loadDownloads()
    }
}
