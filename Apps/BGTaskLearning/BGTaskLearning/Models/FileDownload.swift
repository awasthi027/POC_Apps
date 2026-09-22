import Foundation
import SwiftData

@Model
final class FileDownload {
    @Attribute(.unique) var id: String
    var url: String
    var fileName: String
    var fileSize: Int64
    var downloadedSize: Int64
    var status: DownloadStatus
    var createdAt: Date
    var updatedAt: Date
    var resumeData: Data?
    var localPath: String?
    var error: String?
    var isLocalNotificationEnabled: Bool
    var isLiveActivityEnabled: Bool
    var isFromAPNS: Bool
    
    init(
        url: String,
        fileName: String,
        fileSize: Int64 = 0,
        status: DownloadStatus = .pending,
        isLocalNotificationEnabled: Bool = false,
        isLiveActivityEnabled: Bool = true,
        isFromAPNS: Bool = false
    ) {
        self.id = UUID().uuidString
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.downloadedSize = 0
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isLocalNotificationEnabled = isLocalNotificationEnabled
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.isFromAPNS = isFromAPNS
    }
}

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case completed
    case paused
    case failed
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}
