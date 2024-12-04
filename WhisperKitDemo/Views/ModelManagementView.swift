//
// ModelManagementView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for managing WhisperKit models
struct ModelManagementView: View {
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var settingsModel: SettingsModel
    
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperKitModel?
    @State private var downloadProgress: [WhisperKitModel: Double] = [:]
    
    private let downloadableModels: [WhisperKitModel] = WhisperKitModel.allCases
    
    var body: some View {
        List {
            // Compute Units
            Section {
                Picker("Compute Units", selection: $settingsModel.computeUnits) {
                    ForEach(ComputeUnits.allCases) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
            } header: {
                Text("Performance")
            } footer: {
                Text("Choose which compute units to use for transcription.")
            }
            
            // Installed Models
            Section {
                ForEach(downloadableModels) { model in
                    ModelRowView(
                        model: model,
                        isDownloaded: modelManager.isModelDownloaded(model),
                        isPreferred: settingsModel.preferredModel == model,
                        downloadProgress: downloadProgress[model] ?? 0,
                        onDownload: { downloadModel(model) },
                        onDelete: { confirmDelete(model) },
                        onSelect: { selectModel(model) }
                    )
                }
            } header: {
                Text("Models")
            } footer: {
                Text("Select your preferred model for transcription.")
            }
        }
        .navigationTitle("Model Management")
        .confirmationDialog(
            "Are you sure you want to delete this model?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let model = modelToDelete {
                Text("This will remove the \(model.rawValue) model from your device.")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func downloadModel(_ model: WhisperKitModel) {
        Task {
            do {
                // Start progress tracking
                downloadProgress[model] = 0
                
                // Subscribe to progress updates
                for await progress in modelManager.getDownloadProgress(for: model).values {
                    await MainActor.run {
                        downloadProgress[model] = progress
                    }
                }
                
                // Download model
                try await modelManager.downloadModel(model)
                
                // Clear progress
                await MainActor.run {
                    downloadProgress.removeValue(forKey: model)
                }
            } catch {
                await MainActor.run {
                    downloadProgress.removeValue(forKey: model)
                }
            }
        }
    }
    
    private func deleteModel(_ model: WhisperKitModel) {
        do {
            try modelManager.deleteModel(model)
            modelToDelete = nil
        } catch {
            // Error handling is managed by ErrorManager
        }
    }
    
    private func selectModel(_ model: WhisperKitModel) {
        do {
            try modelManager.selectModel(model)
            settingsModel.preferredModel = model
        } catch {
            // Error handling is managed by ErrorManager
        }
    }
    
    private func confirmDelete(_ model: WhisperKitModel) {
        modelToDelete = model
        showDeleteConfirmation = true
    }
}

/// View for displaying a model row
private struct ModelRowView: View {
    let model: WhisperKitModel
    let isDownloaded: Bool
    let isPreferred: Bool
    let downloadProgress: Double
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.rawValue.capitalized)
                    .font(.headline)
                
                ModelInfoView(model: model)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDownloaded {
                if isPreferred {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Button(action: onSelect) {
                        Text("Select")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            } else if downloadProgress > 0 {
                ProgressView(value: downloadProgress) {
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                }
                .progressViewStyle(.circular)
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// View for displaying model information
private struct ModelInfoView: View {
    let model: WhisperKitModel
    
    var body: some View {
        HStack(spacing: 8) {
            Label(modelSize, systemImage: "arrow.down")
            
            Text("•")
            
            Label(memoryUsage, systemImage: "memorychip")
            
            Text("•")
            
            Label(processingSpeed, systemImage: "speedometer")
        }
    }
    
    private var modelSize: String {
        switch model {
        case .tiny: return "75MB"
        case .base: return "150MB"
        case .small: return "500MB"
        case .medium: return "1.5GB"
        case .large: return "3GB"
        }
    }
    
    private var memoryUsage: String {
        switch model {
        case .tiny: return "~256MB"
        case .base: return "~512MB"
        case .small: return "~1GB"
        case .medium: return "~2.5GB"
        case .large: return "~5GB"
        }
    }
    
    private var processingSpeed: String {
        switch model {
        case .tiny: return "5x"
        case .base: return "4x"
        case .small: return "2x"
        case .medium: return "1x"
        case .large: return "0.5x"
        }
    }
}

#Preview {
    NavigationView {
        ModelManagementView(
            modelManager: PreviewMocks.modelManager,
            settingsModel: PreviewMocks.settingsModel
        )
    }
}
