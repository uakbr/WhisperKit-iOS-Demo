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
    @StateObject private var dependencies = DependencyContainer()
    
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
class DependencyContainer: ObservableObject {
    // MARK: - Core Dependencies
    
    private let errorRecoveryManager: ErrorRecoveryManager
    private let stateRecoveryManager: StateRecoveryManager
    private let crashReporter: CrashReporter
    private let fileManager: FileManaging
    private let errorManager: ErrorHandling
    private let loggingManager: LoggingManager
    
    // MARK: - Feature Dependencies
    
    let modelManager: ModelManaging
    let audioModel: AudioModel
    let transcriptionModel: TranscriptionModel
    let settingsModel: SettingsModel
    let errorModel: ErrorModel
    
    init() {
        // Initialize core dependencies
        do {
            self.errorRecoveryManager = ErrorRecoveryManager()
            self.stateRecoveryManager = StateRecoveryManager()
            self.crashReporter = CrashReporter()
            
            self.loggingManager = LoggingManager()
            
            let errorManager = ErrorManager(
                errorRecoveryManager: errorRecoveryManager,
                stateRecoveryManager: stateRecoveryManager,
                crashReporter: crashReporter
            )
            self.errorManager = errorManager
            
            let fileManager = AudioFileManager(
                errorManager: errorManager
            )
            self.fileManager = fileManager
            
            // Initialize feature dependencies
            let modelManager = ModelManager(
                fileManager: fileManager,
                errorManager: errorManager,
                logger: loggingManager
            )
            self.modelManager = modelManager
            
            self.audioModel = AudioModel(
                fileManager: fileManager,
                errorManager: errorManager,
                logger: loggingManager
            )
            
            let transcriptionManager = TranscriptionManager(
                modelManager: modelManager,
                errorManager: errorManager,
                logger: loggingManager
            )
            
            self.transcriptionModel = TranscriptionModel(
                transcriptionManager: transcriptionManager,
                fileManager: fileManager,
                errorManager: errorManager,
                logger: loggingManager
            )
            
            self.settingsModel = SettingsModel(
                errorManager: errorManager,
                logger: loggingManager
            )
            
            self.errorModel = ErrorModel(
                errorManager: errorManager
            )
        } catch {
            fatalError("Failed to initialize dependencies: \(error)")
        }
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
