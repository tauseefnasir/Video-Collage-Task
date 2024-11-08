//
//  PlayerView.swift
//  Video Collage Task
//
//  Created by Nasir on 08/11/2024.
//

import SwiftUI
import AVFoundation

/// A SwiftUI wrapper for a UIView that displays and loops a video using AVQueuePlayer.
struct PlayerView: UIViewRepresentable {
    var url: URL
    @Binding var player: AVQueuePlayer
    
    func makeUIView(context: Context) -> UIView {
        VideoPlayerUIView(url: url, player: $player)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed as the video URL is not dynamic.
    }
}

/// A UIView subclass responsible for setting up and managing the video playback.
class VideoPlayerUIView: UIView {
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer
    @Binding private var player: AVQueuePlayer
    
    /// Initializes the view with a video URL and  AVQueuePlayer.
    init(url: URL, player: Binding<AVQueuePlayer>) {
        self._player = player
        self.playerLayer = AVPlayerLayer(player: player.wrappedValue)
        super.init(frame: .zero)
        
        configurePlayer(url: url)
        setupPlayerLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up and configures the looper for continuous playback.
    private func configurePlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: playerItem)
        player.play()
        player.isMuted = true // Default to muted playback.
    }
    
    /// Configures the player layer to display video content.
    private func setupPlayerLayer() {
        playerLayer.videoGravity = .resizeAspectFill // Fill the view while maintaining aspect ratio.
        layer.addSublayer(playerLayer)
    }
    
    /// Adjusts the player layer's frame whenever the view's layout changes.
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds // Ensure the video layer matches the view size.
    }
}
