//
//  VideoPlayerViewModel.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import Foundation
import AVFoundation
import Combine
import AVKit

@MainActor
class VideoPlayerViewModel: NSObject, ObservableObject {
    @Published var currentVideo: VideoModel?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    private var timeObserver: Any?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        // Configure audio session on background thread to avoid UI unresponsiveness
        DispatchQueue.global(qos: .default).async {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Use .playback category for video playback
                // .duckOthers - reduce other audio when this plays
                try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("VideoPlayer: Audio session configured")
            } catch {
                print("VideoPlayer: Audio session error - \(error)")
            }
        }
    }

    func playVideo(_ video: VideoModel) {
        currentVideo = video
        print("🎬 Playing: \(video.title)")
        print("📺 URL: \(video.streamingURL)")
        
        let urlAsset = AVURLAsset(url: video.streamingURL)
        let item = AVPlayerItem(asset: urlAsset)
        
        // Add observers for player item status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        if player == nil {
            player = AVPlayer(playerItem: item)
            print("✅ Player created")
        } else {
            player?.replaceCurrentItem(with: item)
            print("✅ Item replaced")
        }

        setupTimeObserver()
        
        // Add delay to ensure player is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.player?.play()
            self?.isPlaying = true
            print("▶️ Playback started, rate: \(self?.player?.rate ?? 0)")
        }
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        print("✅ Video playback ended")
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            DispatchQueue.main.async {
                self?.currentTime = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds, !duration.isNaN {
                    self?.duration = duration
                }
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setupPictureInPicture(with playerViewController: AVPlayerViewController) {
        self.playerViewController = playerViewController
        playerViewController.allowsPictureInPicturePlayback = true
        playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
        
        print("🎥 Configuring PiP:")
        print("   - allowsPictureInPicturePlayback: \(playerViewController.allowsPictureInPicturePlayback)")
        print("   - canStartPictureInPictureAutomaticallyFromInline: \(playerViewController.canStartPictureInPictureAutomaticallyFromInline)")
        
        // iOS will automatically manage PiP when these flags are set
    }

    func startPictureInPicture() {
        // System handles PiP automatically with AVPlayerViewController
        print("📺 PiP will be triggered automatically by system")
    }

    func prepareForBackground() {
        print("📱 App entering background...")
        // Keep player running in background
        if isPlaying {
            print("▶️ Ensuring playback continues in background")
            player?.play()
            
            // Explicitly start PiP
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startPictureInPicture()
                
                if let player = self?.player {
                    print("📺 Background status:")
                    print("   Player rate: \(player.rate)")
                    print("   Player status: \(player.status.rawValue)")
                    print("   Current time: \(player.currentTime().seconds)")
                }
            }
        }
    }

    func resumeFromBackground() {
        print("📱 App returning to foreground...")
        if isPlaying {
            print("▶️ Resuming playback")
            if let player = player {
                print("   Player rate: \(player.rate)")
                print("   Current time: \(player.currentTime().seconds)")
            }
            player?.play()
        }
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
    }
}
