import Foundation
import ActivityKit

/// Shared attributes for the Live Activity that shows download progress
/// on the Lock Screen and Dynamic Island, similar to YouTube's background
/// playback indicator. This file must belong to BOTH the app target and
/// the widget extension target.
struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var fileName: String
        var progress: Double
        var downloadedSize: Int64
        var totalSize: Int64
        var status: String
    }

    var downloadId: String
}
