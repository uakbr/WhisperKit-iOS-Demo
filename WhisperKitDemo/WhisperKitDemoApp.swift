//
// WhisperKitDemoApp.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

@main
struct WhisperKitDemoApp: App {
    private let dependencies = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
                .environmentObject(dependencies.audioModel)
                .environmentObject(dependencies.transcriptionModel)
                .environmentObject(dependencies.settingsModel)
                .environmentObject(dependencies.errorModel)
                .preferredColorScheme(dependencies.settingsModel.theme.colorScheme)
        }
    }
}

/// Container for dependency injection
class DependencyContainer {
    // MARK: - Core Dependencies
    
    private let fileManager: FileManaging
    private let errorManager: ErrorHandling
    private let logger: Logging
    
    // MARK: - Feature Dependencies
    
    let modelManager: ModelManaging
    let audioModel: AudioModel
    let transcriptionModel: TranscriptionModel
    let settingsModel: SettingsModel
    let errorModel: ErrorModel
    
    init() {
        // Initialize core dependencies
        logger = LoggingManager()
        
        fileManager = AudioFileManager(
            logger: logger
        )
        
        errorManager = ErrorManager(
            logger: logger
        )
        
        // Initialize feature dependencies
        modelManager = ModelManager(
            fileManager: fileManager,
            errorManager: errorManager,
            logger: logger
        )
        
        audioModel = AudioModel(
            fileManager: fileManager,
            errorManager: errorManager,
            logger: logger
        )
        
        transcriptionModel = TranscriptionModel(
            transcriptionManager: TranscriptionManager(
                modelManager: modelManager,
                errorManager: errorManager,
                logger: logger
            ),
            fileManager: fileManager,
            errorManager: errorManager,
            logger: logger
        )
        
        settingsModel = SettingsModel(
            errorManager: errorManager,
            logger: logger
        )
        
        errorModel = ErrorModel(
            errorManager: errorManager
        )
    }
}

private extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
