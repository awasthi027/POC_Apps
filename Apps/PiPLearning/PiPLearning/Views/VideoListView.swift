//
//  VideoListView.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import SwiftUI

struct VideoListView: View {
    @ObservedObject var viewModel: VideoListViewModel
    @ObservedObject var playerViewModel: VideoPlayerViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEach(viewModel.videos) { video in
                            VideoListItemView(
                                video: video,
                                isSelected: playerViewModel.currentVideo?.id == video.id
                            )
                            .onTapGesture {
                                viewModel.selectVideo(video)
                                playerViewModel.playVideo(video)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Live Streams")
        }
    }
}

struct VideoListItemView: View {
    let video: VideoModel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(video.thumbnail ?? "📹")
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let description = video.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .flex()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

extension View {
    func flex() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VideoListView(
        viewModel: VideoListViewModel(),
        playerViewModel: VideoPlayerViewModel()
    )
}
