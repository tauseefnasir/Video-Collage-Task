//
//  ContentView.swift
//  Video Collage Task
//
//  Created by Nasir on 06/11/2024.
//

import SwiftUI
import AVFoundation
import PhotosUI
import AVKit


struct ContentView: View {
    @State private var selectedVideosURL: [URL] = []
    @State private var showPicker = false
    @State private var isLoading = false
    @State private var navigateToCollage = false
    @State private var videoPlayers: [AVQueuePlayer] = []
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView {
                        Text("Loading videos")
                            .foregroundStyle(Color.accentColor)
                    }
                    .scaleEffect(1.4)
                } else {
                    Text("Select 3 videos")
                        .font(.headline)
                }
                NavigationLink(
                    destination: VideoCollageView(videoURLs: selectedVideosURL, players: $videoPlayers),
                    isActive: $navigateToCollage
                ) {
                    EmptyView()
                }
            }
            .navigationTitle("Video Collage")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        requestPhotoLibraryPermission { granted in
                            if granted {
                                showPicker.toggle()
                            } else {
                                alertMessage = "Please allow access to Photos to proceed."
                                showAlert = true
                            }
                        }
                    } label: {
                        Label("Select Three Videos", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                VideoPicker(
                    selectedVideos: $selectedVideosURL,
                    isLoading: $isLoading,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage,
                    onComplete: {
                        setupVideoPlayers()
                        navigateToCollage = true
                    }
                )
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func setupVideoPlayers() {
        videoPlayers = selectedVideosURL.map { _ in AVQueuePlayer() }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    completion(true)
                default:
                    completion(false)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
