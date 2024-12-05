//
// ContentView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// Main content view providing navigation between app sections
struct ContentView: View {
    @StateObject private var audioModel: AudioModel
    @StateObject private var transcriptionModel: TranscriptionModel
    @StateObject private var settingsModel: SettingsModel
    @StateObject private var errorModel: ErrorModel
    
    @State private var selectedTab = Tab.transcribe
    @State private var showNewRecording = false
    
    init(dependencies: DependencyContainer) {
        _audioModel = StateObject(wrappedValue: dependencies.audioModel)
        _transcriptionModel = StateObject(wrappedValue: dependencies.transcriptionModel)
        _settingsModel = StateObject(wrappedValue: dependencies.settingsModel)
        _errorModel = StateObject(wrappedValue: dependencies.errorModel)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Transcribe Tab
            NavigationView {
                VStack(spacing: 0) {
                    // Audio Player
                    if let audioURL = audioModel.audioURL {
                        AudioPlayerView(audioModel: audioModel)
                            .padding()
                    }
                    
                    // Transcription Content
                    if transcriptionModel.isTranscribing {
                        TranscriptionProgressView(
                            progress: transcriptionModel.transcriptionProgress
                        )
                    } else if let transcription = transcriptionModel.transcriptions.last {
                        TranscriptionResultView(
                            transcription: transcription,
                            audioModel: audioModel
                        )
                    } else {
                        EmptyStateView()
                    }
                    
                    // Record Button
                    RecordButton(isRecording: audioModel.isRecording) {
                        if audioModel.isRecording {
                            audioModel.stopRecording()
                        } else {
                            audioModel.startRecording()
                        }
                    }
                    .padding(.bottom)
                }
                .navigationTitle("Transcribe")
                .navigationBarItems(
                    leading: Button(action: showFileImporter) {
                        Image(systemName: "doc")
                    },
                    trailing: Button(action: { showNewRecording = true }) {
                        Image(systemName: "plus")
                    }
                )
            }
            .tabItem {
                Label("Transcribe", systemImage: "mic")
            }
            .tag(Tab.transcribe)
            
            // History Tab
            NavigationView {
                HistoryView(transcriptionModel: transcriptionModel)
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(Tab.history)
            
            // Settings Tab
            NavigationView {
                SettingsView(settingsModel: settingsModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $showNewRecording) {
            NewRecordingView(
                audioModel: audioModel,
                transcriptionModel: transcriptionModel
            )
        }
        .alert("Error", isPresented: $errorModel.showErrorAlert, presenting: errorModel.currentError) { error in
            Button("OK", role: .cancel) {
                errorModel.dismissError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func showFileImporter() {
        // TODO: Implement file import functionality
    }
}

// MARK: - Supporting Views

/// View showing transcription progress
private struct TranscriptionProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                Text("Transcribing...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
            }
            .progressViewStyle(.circular)
            .padding()
        }
    }
}

/// View showing empty state when no transcription is available
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Record or import audio to get started")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Your transcriptions will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// Button for starting/stopping recording
private struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 64, height: 64)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
}

// MARK: - Supporting Types

private enum Tab {
    case transcribe
    case history
    case settings
}

#Preview {
    ContentView(dependencies: PreviewMocks.dependencies)
}
