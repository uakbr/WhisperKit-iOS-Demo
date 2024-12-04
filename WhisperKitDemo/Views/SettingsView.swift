//
// SettingsView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for managing application settings
struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    @State private var showLanguageSelection = false
    @State private var showModelManagement = false
    @State private var showImportSettings = false
    @State private var showExportSettings = false
    
    var body: some View {
        List {
            // Audio Settings
            Section {
                Picker("Audio Quality", selection: $settingsModel.audioQuality) {
                    ForEach(AudioQuality.allCases) { quality in
                        Text(quality.rawValue)
                            .tag(quality)
                    }
                }
                
                Picker("Audio Format", selection: $settingsModel.audioFormat) {
                    ForEach(AudioFormat.allCases) { format in
                        Text(format.rawValue)
                            .tag(format)
                    }
                }
            } header: {
                Text("Audio")
            } footer: {
                Text("Higher quality audio requires more storage space.")
            }
            
            // Transcription Settings
            Section {
                NavigationLink {
                    ModelManagementView(modelManager: modelManager,
                                       settingsModel: settingsModel)
                } label: {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(settingsModel.preferredModel.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink {
                    LanguageSelectionView(settingsModel: settingsModel)
                } label: {
                    HStack {
                        Text("Language")
                        Spacer()
                        if settingsModel.autoDetectLanguage {
                            Text("Auto-detect")
                                .foregroundColor(.secondary)
                        } else {
                            Text(Locale.current.localizedString(forLanguageCode: settingsModel.selectedLanguage) ?? settingsModel.selectedLanguage)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Picker("Task", selection: $settingsModel.transcriptionTask) {
                    ForEach(TranscriptionTask.allCases) { task in
                        Text(task.rawValue)
                            .tag(task)
                    }
                }
            } header: {
                Text("Transcription")
            }
            
            // Interface Settings
            Section {
                Picker("Theme", selection: $settingsModel.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue)
                            .tag(theme)
                    }
                }
                
                Toggle("Show Timestamps", isOn: $settingsModel.showTimestamps)
            } header: {
                Text("Interface")
            }
            
            // Data Management
            Section {
                Button(action: { showImportSettings = true }) {
                    Label("Import Settings", systemImage: "square.and.arrow.down")
                }
                
                Button(action: { showExportSettings = true }) {
                    Label("Export Settings", systemImage: "square.and.arrow.up")
                }
                
                Button(action: settingsModel.resetToDefaults) {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .foregroundColor(.red)
                }
            } header: {
                Text("Data")
            }
            
            // About
            Section {
                Link(destination: URL(string: "https://github.com/mlc-ai/whisperkit")!) {
                    Label("WhisperKit Documentation", systemImage: "book")
                }
                
                Link(destination: URL(string: "https://github.com/openai/whisper")!) {
                    Label("OpenAI Whisper", systemImage: "link")
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.version)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .fileImporter(
            isPresented: $showImportSettings,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try Data(contentsOf: url)
                    try settingsModel.importSettings(data)
                } catch {
                    // Error handling managed by ErrorManager
                }
            case .failure:
                break
            }
        }
        .fileExporter(
            isPresented: $showExportSettings,
            document: SettingsDocument(settingsModel: settingsModel),
            contentType: .json,
            defaultFilename: "whisperkit_settings.json"
        ) { _ in }
    }
}

// MARK: - Supporting Types

private struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let settingsModel: SettingsModel
    
    init(settingsModel: SettingsModel) {
        self.settingsModel = settingsModel
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("Import not supported")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try settingsModel.exportSettings()
        return .init(regularFileWithContents: data)
    }
}

private extension Bundle {
    var version: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

#Preview {
    NavigationView {
        SettingsView(settingsModel: PreviewMocks.settingsModel)
    }
}
