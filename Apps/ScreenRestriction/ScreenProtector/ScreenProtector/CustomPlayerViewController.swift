//
//  CustomPlayerViewController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 10/09/25.
//

import UIKit
import AVFoundation
import SecureScreen

class CustomPlayerViewController: UIViewController {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?

    // UI Components
    private let playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Play", for: .normal)
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view = SecureViewService.shared.getSecuredView(self.view,
                                                            shouldShowRestrictionMessage: true)
        setupUI()
        setupPlayer()
    }

    private func setupUI() {
        view.backgroundColor = .black

        // Add play/pause button
        view.addSubview(playPauseButton)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupPlayer() {
        guard let videoURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4") else {
            print("Invalid URL")
            return
        }

        // Create player item
        playerItem = AVPlayerItem(url: videoURL)

        // Create player
        player = AVPlayer(playerItem: playerItem)

        // Create player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = view.bounds

        // Add player layer to view
        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }
        self.view = SecureViewService.shared.getSecuredView(self.view,
                                                            shouldShowRestrictionMessage: true)
        // Bring button to front
        view.bringSubviewToFront(playPauseButton)

        // Add observer for player item status
        playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            if item.status == .failed {
                print("Player item failed: \(item.error?.localizedDescription ?? "Unknown error")")
            } else if item.status == .readyToPlay {
                print("Player item is ready to play")
            }
        }
    }

    @objc private func playPauseTapped() {
        if player?.rate == 0 {
            player?.play()
            playPauseButton.setTitle("Pause", for: .normal)
        } else {
            player?.pause()
            playPauseButton.setTitle("Play", for: .normal)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
        playerItem?.removeObserver(self, forKeyPath: "status")
    }

    deinit {
        player?.pause()
        playerItem?.removeObserver(self, forKeyPath: "status")
    }
}
