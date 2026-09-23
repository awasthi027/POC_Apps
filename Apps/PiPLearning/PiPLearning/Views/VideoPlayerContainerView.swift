//
//  VideoPlayerView.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import SwiftUI
import AVKit

struct VideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: VideoPlayerViewModel

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = viewModel.player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        print("🎥 AVPlayerViewController created")
        print("   - PiP allowed: \(controller.allowsPictureInPicturePlayback)")
        print("   - Auto PiP inline: \(controller.canStartPictureInPictureAutomaticallyFromInline)")
        
        viewModel.setupPictureInPicture(with: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = viewModel.player
    }
}

struct VideoPlayerContainerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                if let video = viewModel.currentVideo {
                    Text(video.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    VideoPlayerView(viewModel: viewModel)
                        .frame(height: 300)
                        .cornerRadius(8)

                    VStack(spacing: 8) {
                        HStack {
                            Text(formatTime(viewModel.currentTime))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Slider(
                                value: $viewModel.currentTime,
                                in: 0...max(viewModel.duration, 1)
                            ) { _ in
                                viewModel.seek(to: viewModel.currentTime)
                            }
                            
                            Text(formatTime(viewModel.duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        HStack(spacing: 20) {
                            Button(action: {
                                viewModel.togglePlayPause()
                            }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    if let description = video.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding()
                    }

                    Spacer()
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

#Preview {
    VideoPlayerContainerView(viewModel: VideoPlayerViewModel())
}
