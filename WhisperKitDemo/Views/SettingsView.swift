//
// SettingsView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for managing application settings
struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    @ObservedObject var modelManager: ModelManager
    
    @State private var showLanguageSelection = false
    @State private var showModelManagement = false
    @State private var showImportSettings = false
    @State private var showExportSettings = false
    
    var body: some View {
        // ... rest of the view implementation stays the same ...
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
        SettingsView(
            settingsModel: PreviewMocks.settingsModel,
            modelManager: PreviewMocks.modelManager
        )
    }
}
