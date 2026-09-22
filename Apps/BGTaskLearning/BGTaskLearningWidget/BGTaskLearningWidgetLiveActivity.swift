import ActivityKit
import WidgetKit
import SwiftUI

struct BGTaskLearningWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenDownloadView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(for: context.state.status))
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.fileName)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.state.status))
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
            } minimal: {
                Image(systemName: iconName(for: context.state.status))
            }
        }
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "Completed": return "checkmark.circle.fill"
        case "Failed": return "xmark.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }
}

private struct LockScreenDownloadView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.fileName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                ProgressView(value: context.state.progress)
                    .tint(.blue)

                Text(subtitleText)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(Int(context.state.progress * 100))%")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
    }

    private var iconName: String {
        switch context.state.status {
        case "Completed": return "checkmark.circle.fill"
        case "Failed": return "xmark.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private var iconColor: Color {
        switch context.state.status {
        case "Completed": return .green
        case "Failed": return .red
        default: return .blue
        }
    }

    private var subtitleText: String {
        switch context.state.status {
        case "Completed": return "Download complete"
        case "Failed": return "Download failed"
        default:
            let downloaded = ByteCountFormatter.string(fromByteCount: context.state.downloadedSize, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: context.state.totalSize, countStyle: .file)
            return "\(downloaded) of \(total)"
        }
    }
}
