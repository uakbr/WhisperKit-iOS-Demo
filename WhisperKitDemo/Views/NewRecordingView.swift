//
// NewRecordingView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

struct NewRecordingView: View {
    @ObservedObject var audioModel: AudioModel
    @ObservedObject var transcriptionModel: TranscriptionModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isTranscribing = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Recording Time Display
                Text(formatTime(recordingTime))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(audioModel.isRecording ? .red : .primary)
                
                // Audio Visualizer
                if audioModel.isRecording {
                    AudioVisualizerView()
                        .frame(height: 100)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
                
                // Record Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(audioModel.isRecording ? .red : .accentColor)
                            .frame(width: 80, height: 80)
                        
                        if audioModel.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .disabled(isTranscribing)
                
                // Transcribe Button
                if !audioModel.isRecording && audioModel.audioURL != nil {
                    Button(action: transcribe) {
                        if isTranscribing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Transcribe")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTranscribing)
                }
            }
            .padding()
            .navigationTitle("New Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cleanup()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(audioModel.isRecording || isTranscribing)
    }
    
    private func toggleRecording() {
        if audioModel.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        audioModel.startRecording()
        startTimer()
    }
    
    private func stopRecording() {
        audioModel.stopRecording()
        stopTimer()
    }
    
    private func transcribe() {
        guard let audioURL = audioModel.audioURL else { return }
        
        isTranscribing = true
        Task {
            do {
                try await transcriptionModel.transcribe(audioURL: audioURL)
                dismiss()
            } catch {
                // Error handling is managed by ErrorManager
                isTranscribing = false
            }
        }
    }
    
    private func cleanup() {
        if audioModel.isRecording {
            audioModel.stopRecording()
        }
        stopTimer()
    }
    
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

struct AudioVisualizerView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.2, count: 30)
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.red)
                    .frame(width: 4, height: levels[index] * 100)
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .onReceive(timer) { _ in
            for index in levels.indices {
                levels[index] = CGFloat.random(in: 0.2...1.0)
            }
        }
    }
}

#if DEBUG
struct NewRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        NewRecordingView(
            audioModel: PreviewMocks.audioModel,
            transcriptionModel: PreviewMocks.transcriptionModel
        )
    }
}
#endif
