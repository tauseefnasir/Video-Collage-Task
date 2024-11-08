//
//  VideoPicker.swift
//  Video Collage Task
//
//  Created by Nasir on 06/11/2024.
//

import Foundation
import SwiftUI
import PhotosUI

/// A view that wraps `PHPickerViewController` to allow users to select multiple videos.
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideos: [URL]
    @Binding var isLoading: Bool
    @Binding var showAlert: Bool
    @Binding var alertMessage: String?
    var onComplete: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 3

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            parent.selectedVideos.removeAll()

            // Don't proceed if selected videos are less than 3.
            guard results.count == 3 else {
                parent.alertMessage = "You must select 3 videos to proceed"
                parent.showAlert = true
                return
            }

            parent.isLoading = true
            let dispatchGroup = DispatchGroup()

            for result in results {
                if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                    dispatchGroup.enter()

                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { (url, error) in
                        defer { dispatchGroup.leave() }

                        if let tempURL = url {
                            do {
                                // Obtain the app's documents directory.
                                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

                                // Create a destination URL by appending the video file's name.
                                let destinationURL = documentsURL.appendingPathComponent(tempURL.lastPathComponent)

                                // Remove any existing file at the destination to avoid conflicts.
                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    try FileManager.default.removeItem(at: destinationURL)
                                }

                                // Copy the video from the temporary URL to the documents directory.
                                try FileManager.default.copyItem(at: tempURL, to: destinationURL)

                                DispatchQueue.main.async {
                                    // Append the copied video’s URL to the selected videos list on the main thread.
                                    self.parent.selectedVideos.append(destinationURL)
                                }
                            } catch {
                                print("Error copying file: \(error)")
                                DispatchQueue.main.async {
                                    self.parent.alertMessage = "Failed to process video file."
                                    self.parent.showAlert = true
                                }
                            }
                        } else if let error = error {
                            print("Error loading file: \(error)")
                            DispatchQueue.main.async {
                                self.parent.alertMessage = "An error occurred while loading videos."
                                self.parent.showAlert = true
                            }
                        }
                    }
                }
            }

            // Notify once all video processing tasks have completed.
            dispatchGroup.notify(queue: .main) {
                self.parent.isLoading = false
                if self.parent.selectedVideos.count == 3 {
                    self.parent.onComplete()
                } else {
                    self.parent.alertMessage = "Some videos could not be loaded. Please try again."
                    self.parent.showAlert = true
                }
            }
        }
    }
}
