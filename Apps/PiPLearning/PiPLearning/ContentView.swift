//
//  ContentView.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var videoListViewModel = VideoListViewModel()
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if let _ = playerViewModel.currentVideo {
                    VideoPlayerContainerView(viewModel: playerViewModel)
                        .frame(height: 350)
                }

                VideoListView(
                    viewModel: videoListViewModel,
                    playerViewModel: playerViewModel
                )
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                playerViewModel.prepareForBackground()
            } else if newPhase == .active {
                playerViewModel.resumeFromBackground()
            }
        }
    }
}

#Preview {
    ContentView()
}
