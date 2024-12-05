//
// TranscriptionResultView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

struct TranscriptionResultView: View {
    let result: TranscriptionResult
    @ObservedObject var audioModel: AudioModel
    @Environment(\.settingsModel) var settings
    
    @State private var selectedSegmentID: UUID?
    @State private var isPlaying = false
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata Section
                VStack(alignment: .leading, spacing: 8) {
                    if let language = result.language {
                        Label(
                            Locale.current.localizedString(forLanguageCode: language) ?? language,
                            systemImage: "globe"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    
                    Label(
                        formatDuration(result.duration),
                        systemImage: "clock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
                
                // Full Text Section
                Text(result.text)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                
                if settings.showTimestamps {
                    // Segments Section
                    ForEach(result.segments) { segment in
                        SegmentView(segment: segment,
                                   isSelected: selectedSegmentID == segment.id,
                                   onTap: { seekToSegment(segment) })
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Transcription Result")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [result.text])
        }
    }
    
    private func seekToSegment(_ segment: TranscriptionSegment) {
        selectedSegmentID = segment.id
        audioModel.seek(to: segment.start)
        
        if !audioModel.isPlaying {
            audioModel.startPlayback()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

private struct SegmentView: View {
    let segment: TranscriptionSegment
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formatTimestamp(segment.start))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatTimestamp(segment.end))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(segment.probability * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(segment.text)
                    .font(.body)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
struct TranscriptionResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TranscriptionResultView(
                result: PreviewMocks.transcriptionResult,
                audioModel: PreviewMocks.audioModel
            )
        }
    }
}
#endif
