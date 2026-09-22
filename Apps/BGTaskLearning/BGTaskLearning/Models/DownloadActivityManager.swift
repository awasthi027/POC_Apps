import Foundation
import ActivityKit

/// Manages the lifecycle of Live Activities for background downloads.
/// A Live Activity shows real-time download progress on the Lock Screen
/// and Dynamic Island even while the app is backgrounded — similar to
/// how YouTube shows a persistent control while playing audio in background.
@available(iOS 16.1, *)
final class DownloadActivityManager {
    static let shared = DownloadActivityManager()

    private var activities: [String: Activity<DownloadActivityAttributes>] = [:]

    private init() {}

    func startActivity(downloadId: String, fileName: String, totalSize: Int64) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        // If an activity already exists for this download, don't start a new one
        if activities[downloadId] != nil { return }

        let attributes = DownloadActivityAttributes(downloadId: downloadId)
        let initialState = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: 0,
            downloadedSize: 0,
            totalSize: totalSize,
            status: "Downloading"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activities[downloadId] = activity
            print("Started Live Activity for \(fileName)")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateActivity(downloadId: String, fileName: String, downloadedSize: Int64, totalSize: Int64) {
        guard let activity = activities[downloadId] else { return }

        let progress = totalSize > 0 ? Double(downloadedSize) / Double(totalSize) : 0
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            status: "Downloading"
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity(downloadId: String, fileName: String, success: Bool) {
        guard let activity = activities[downloadId] else { return }

        let finalState = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: success ? 1.0 : 0.0,
            downloadedSize: 0,
            totalSize: 0,
            status: success ? "Completed" : "Failed"
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 5))
            activities.removeValue(forKey: downloadId)
        }
    }
}
