//
//  VideoListViewModel.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import Foundation
import Combine

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var videos: [VideoModel] = []
    @Published var isLoading = false
    @Published var selectedVideo: VideoModel?

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadPublicStreamingUrls()
    }

    func loadPublicStreamingUrls() {
        isLoading = true
        
        videos = [
            VideoModel(
                title: "DW (Deutsche Welle) English",
                streamingURL: URL(string: "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8")!,
                thumbnail: "📺",
                description: "Mux HLS test stream"
            ),
             VideoModel(
                 title: "Apple Bipbop Stream",
                 streamingURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!,
                 thumbnail: "🍎",
                 description: "Apple HLS sample stream"
             )
         ]
        
        isLoading = false
    }

    func selectVideo(_ video: VideoModel) {
        selectedVideo = video
    }
}
