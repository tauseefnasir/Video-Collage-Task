//
//  VideoCollageView.swift
//  Video Collage Task
//
//  Created by Nasir on 08/11/2024.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct VideoCollageView: View {
    let videoURLs: [URL]
    @Binding var players: [AVQueuePlayer]
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State var isLoading = false
    @State private var areVideosPlaying = true
    @State private var exportProgress: Float = 0.0
    
    var body: some View {
        GeometryReader { geometry in
                VStack(spacing: 0) {
                    if isLoading {
                        VStack {
                            ProgressView(value: exportProgress, total: 1.0)
                                .padding()
                            Text("Exporting: \(Int(exportProgress * 100))%")
                                .font(.subheadline)
                        }
                    }
                    // Display each video in a PlayerView, dividing the screen equally.
                    ForEach(0..<videoURLs.count, id: \.self) { index in
                        PlayerView(url: videoURLs[index], player: $players[index])
                            .frame(height: geometry.size.height / 3)
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pauseAndPlayAllVideos()
                } label: {
                    if areVideosPlaying {
                        Label("Pause Videos", systemImage: "pause.fill")
                    } else {
                        Label("Play Videos", systemImage: "play.fill")
                    }
                    
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export") {
                    exportVideo()
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Message"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
}

extension VideoCollageView {
    
    /// Pauses and plays playback for all videos in the collage.
    private func pauseAndPlayAllVideos() {
        for player in players {
            areVideosPlaying ? player.pause() : player.play()
        }
        areVideosPlaying.toggle()
        
    }
    
    /// Prepares and exports the video collage.
    private func exportVideo() {
        pauseAndPlayAllVideos()
        isLoading = true
        exportProgress = 0.0
        
        createAndExportCollage(videoURLs: videoURLs) { result in
            isLoading = false
            switch result {
            case .success(let url):
                alertMessage = "Video saved in gallery with name \(url.lastPathComponent)"
            case .failure(let error):
                alertMessage = "Export failed: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
    
    /// Saves the exported video to the Photos Library.
    private func saveToPhotosLibrary(outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(outputURL))
                } else {
                    completion(.failure(error ?? NSError(domain: "Saving to Photos failed", code: 0, userInfo: nil)))
                }
            }
        }
    }
    
        /// Combines and exports the videos as a single collage, saving it to the Photos Library.
        private func createAndExportCollage(videoURLs: [URL], completion: @escaping (Result<URL, Error>) -> Void) {
            let composition = AVMutableComposition()
            let videoComposition = AVMutableVideoComposition()
            let outputSize = CGSize(width: 1080, height: 1920)
            videoComposition.renderSize = outputSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    
            let mainInstruction = AVMutableVideoCompositionInstruction()
            // This instruction will hold the layer instructions for all the videos.
            // It defines how multiple video tracks should be composed into a single output.
    
            var maxDuration = CMTime.zero
            // Tracks the maximum duration among all video tracks to set the time range of the main instruction.
    
            for (index, videoURL) in videoURLs.enumerated() {
                let asset = AVAsset(url: videoURL)
                // Load the video asset from the given URL.
    
                guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                    // Ensure the asset contains a video track; if not, report failure.
                    completion(.failure(NSError(domain: "Missing video track", code: 0, userInfo: nil)))
                    return
                }
    
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                // Define the time range for the video track (start to end of the video).
    
                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    // Attempt to add a mutable track to the composition for the current video.
                    // If it fails, report an error.
                    completion(.failure(NSError(domain: "Track creation failed", code: 0, userInfo: nil)))
                    return
                }
    
                do {
                    try compositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                    // Insert the time range of the video track into the composition track.
                } catch {
                    completion(.failure(error))
                    return
                }
    
                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
                // Create a layer instruction for the current video track to define its transformation.
    
                let videoHeight = outputSize.height / CGFloat(videoURLs.count)
                // Calculate the height for each video within the collage frame. i.e 1/3
    
                let transform = CGAffineTransform(translationX: 0, y: videoHeight * CGFloat(index))
                    .scaledBy(x: outputSize.width / videoTrack.naturalSize.width,
                              y: videoHeight / videoTrack.naturalSize.height)
                // Apply translation and scaling to fit each video into its designated portion of the frame.
    
                instruction.setTransform(transform, at: .zero)
                mainInstruction.layerInstructions.append(instruction)
                // Add the layer instruction to the main instruction.
    
                maxDuration = max(maxDuration, asset.duration)
                // Update the maximum duration to ensure the collage accommodates the longest video.
            }
    
            mainInstruction.timeRange = CMTimeRange(start: .zero, duration: maxDuration)
            videoComposition.instructions = [mainInstruction]
            // Set the main instruction to apply to the entire composition duration.
    
            let outputPath = NSTemporaryDirectory() + "collageVideo.mp4"
            let outputURL = URL(fileURLWithPath: outputPath)
    
            if FileManager.default.fileExists(atPath: outputPath) {
                try? FileManager.default.removeItem(atPath: outputPath)
                // Remove the file if it already exists at the output path.
            }
    
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                // Create an export session for the composition. If it fails, report an error.
                completion(.failure(NSError(domain: "Export session creation failed", code: 0, userInfo: nil)))
                return
            }
    
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = videoComposition
    
            // Update the progress periodically.
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                exportProgress = exportSession.progress
                if exportSession.progress >= 1.0 {
                    timer.invalidate()
                }
            }
    
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        saveToPhotosLibrary(outputURL: outputURL, completion: completion)
                    case .failed, .cancelled:
                        completion(.failure(exportSession.error ?? NSError(domain: "Export failed", code: 0, userInfo: nil)))
                    default:
                        break
                    }
                }
            }
        }



}
