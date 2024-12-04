//
// AudioPlayerView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for audio playback controls and visualization
struct AudioPlayerView: View {
    @ObservedObject var audioModel: AudioModel
    @State private var isHovering = false
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(in: geometry), height: 4)
                    
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .offset(x: progressWidth(in: geometry) - 6)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = value.location.x / geometry.size.width
                                    seekAudio(progress: progress)
                                }
                        )
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .onEnded { value in
                            let progress = value.location.x / geometry.size.width
                            seekAudio(progress: progress)
                        }
                )
            }
            .frame(height: 12)
            
            // Time Labels
            HStack {
                Text(formatTime(audioModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(audioModel.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Playback Controls
            HStack(spacing: 24) {
                Button(action: skipBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                
                Button(action: togglePlayback) {
                    Image(systemName: audioModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                
                Button(action: skipForward) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .onReceive(timer) { _ in
            // Update progress
        }
    }
    
    // MARK: - Helper Methods
    
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        let progress = audioModel.currentTime / audioModel.duration
        return geometry.size.width * CGFloat(progress)
    }
    
    private func seekAudio(progress: CGFloat) {
        let time = Double(progress) * audioModel.duration
        audioModel.seek(to: time)
    }
    
    private func togglePlayback() {
        if audioModel.isPlaying {
            audioModel.pausePlayback()
        } else {
            audioModel.startPlayback()
        }
    }
    
    private func skipForward() {
        let newTime = min(audioModel.currentTime + 15, audioModel.duration)
        audioModel.seek(to: newTime)
    }
    
    private func skipBackward() {
        let newTime = max(audioModel.currentTime - 15, 0)
        audioModel.seek(to: newTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    AudioPlayerView(audioModel: AudioModel(
        fileManager: PreviewMocks.fileManager,
        errorManager: PreviewMocks.errorManager,
        logger: PreviewMocks.logger
    ))
    .padding()
}
