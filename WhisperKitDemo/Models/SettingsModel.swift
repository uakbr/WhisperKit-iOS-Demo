//
// SettingsModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine
import WhisperKit

/// Model class representing application settings
public class SettingsModel: ObservableObject {
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let errorManager: ErrorHandling
    private let logger: Logging
    
    // Audio Settings
    @Published var audioQuality: AudioQuality {
        didSet {
            userDefaults.set(audioQuality.rawValue, forKey: UserDefaultsKeys.audioQuality)
            logger.info("Audio quality changed to: \(audioQuality.rawValue)")
        }
    }
    
    @Published var audioFormat: AudioFormat {
        didSet {
            userDefaults.set(audioFormat.rawValue, forKey: UserDefaultsKeys.audioFormat)
            logger.info("Audio format changed to: \(audioFormat.rawValue)")
        }
    }
    
    // Transcription Settings
    @Published var selectedLanguage: String {
        didSet {
            userDefaults.set(selectedLanguage, forKey: UserDefaultsKeys.selectedLanguage)
            logger.info("Selected language changed to: \(selectedLanguage)")
        }
    }
    
    @Published var autoDetectLanguage: Bool {
        didSet {
            userDefaults.set(autoDetectLanguage, forKey: UserDefaultsKeys.autoDetectLanguage)
            logger.info("Auto detect language changed to: \(autoDetectLanguage)")
        }
    }
    
    @Published var transcriptionTask: TranscriptionTask {
        didSet {
            userDefaults.set(transcriptionTask.rawValue, forKey: UserDefaultsKeys.transcriptionTask)
            logger.info("Transcription task changed to: \(transcriptionTask.rawValue)")
        }
    }
    
    // Model Settings
    @Published var preferredModel: WhisperKitModel {
        didSet {
            userDefaults.set(preferredModel.rawValue, forKey: UserDefaultsKeys.preferredModel)
            logger.info("Preferred model changed to: \(preferredModel.rawValue)")
        }
    }
    
    @Published var computeUnits: ComputeUnits {
        didSet {
            userDefaults.set(computeUnits.rawValue, forKey: UserDefaultsKeys.computeUnits)
            logger.info("Compute units changed to: \(computeUnits.rawValue)")
        }
    }
    
    // UI Settings
    @Published var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: UserDefaultsKeys.theme)
            logger.info("Theme changed to: \(theme.rawValue)")
        }
    }
    
    @Published var showTimestamps: Bool {
        didSet {
            userDefaults.set(showTimestamps, forKey: UserDefaultsKeys.showTimestamps)
            logger.info("Show timestamps changed to: \(showTimestamps)")
        }
    }
    
    // MARK: - Initialization
    
    init(errorManager: ErrorHandling, logger: Logging) {
        self.errorManager = errorManager
        self.logger = logger.scoped(for: "SettingsModel")
        
        // Initialize properties with stored values or defaults
        self.audioQuality = AudioQuality(rawValue: userDefaults.string(forKey: UserDefaultsKeys.audioQuality) ?? "") ?? .high
        self.audioFormat = AudioFormat(rawValue: userDefaults.string(forKey: UserDefaultsKeys.audioFormat) ?? "") ?? .wav
        self.selectedLanguage = userDefaults.string(forKey: UserDefaultsKeys.selectedLanguage) ?? "en"
        self.autoDetectLanguage = userDefaults.bool(forKey: UserDefaultsKeys.autoDetectLanguage)
        self.transcriptionTask = TranscriptionTask(rawValue: userDefaults.string(forKey: UserDefaultsKeys.transcriptionTask) ?? "") ?? .transcribe
        self.preferredModel = WhisperKitModel(rawValue: userDefaults.string(forKey: UserDefaultsKeys.preferredModel) ?? "") ?? .tiny
        self.computeUnits = ComputeUnits(rawValue: userDefaults.string(forKey: UserDefaultsKeys.computeUnits) ?? "") ?? .cpuAndNeuralEngine
        self.theme = AppTheme(rawValue: userDefaults.string(forKey: UserDefaultsKeys.theme) ?? "") ?? .system
        self.showTimestamps = userDefaults.bool(forKey: UserDefaultsKeys.showTimestamps)
    }
    
    // MARK: - Public Methods
    
    /// Resets all settings to their default values
    public func resetToDefaults() {
        audioQuality = .high
        audioFormat = .wav
        selectedLanguage = "en"
        autoDetectLanguage = false
        transcriptionTask = .transcribe
        preferredModel = .tiny
        computeUnits = .cpuAndNeuralEngine
        theme = .system
        showTimestamps = true
        
        logger.info("Reset all settings to defaults")
    }
    
    /// Exports settings as JSON
    public func exportSettings() throws -> Data {
        let settings = SettingsExport(
            audioQuality: audioQuality,
            audioFormat: audioFormat,
            selectedLanguage: selectedLanguage,
            autoDetectLanguage: autoDetectLanguage,
            transcriptionTask: transcriptionTask,
            preferredModel: preferredModel,
            computeUnits: computeUnits,
            theme: theme,
            showTimestamps: showTimestamps
        )
        
        return try JSONEncoder().encode(settings)
    }
    
    /// Imports settings from JSON
    public func importSettings(_ data: Data) throws {
        let settings = try JSONDecoder().decode(SettingsExport.self, from: data)
        
        audioQuality = settings.audioQuality
        audioFormat = settings.audioFormat
        selectedLanguage = settings.selectedLanguage
        autoDetectLanguage = settings.autoDetectLanguage
        transcriptionTask = settings.transcriptionTask
        preferredModel = settings.preferredModel
        computeUnits = settings.computeUnits
        theme = settings.theme
        showTimestamps = settings.showTimestamps
        
        logger.info("Imported settings successfully")
    }
}

// MARK: - Supporting Types

public enum AudioQuality: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public enum AudioFormat: String, CaseIterable, Codable {
    case wav = "WAV"
    case m4a = "M4A"
    case mp3 = "MP3"
}

public enum TranscriptionTask: String, CaseIterable, Codable {
    case transcribe = "Transcribe"
    case translate = "Translate"
}

public enum ComputeUnits: String, CaseIterable, Codable {
    case cpu = "CPU Only"
    case neuralEngine = "Neural Engine Only"
    case cpuAndNeuralEngine = "CPU and Neural Engine"
}

public enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

/// Structure for exporting/importing settings
private struct SettingsExport: Codable {
    let audioQuality: AudioQuality
    let audioFormat: AudioFormat
    let selectedLanguage: String
    let autoDetectLanguage: Bool
    let transcriptionTask: TranscriptionTask
    let preferredModel: WhisperKitModel
    let computeUnits: ComputeUnits
    let theme: AppTheme
    let showTimestamps: Bool
}

// MARK: - Constants

private enum UserDefaultsKeys {
    static let audioQuality = "audioQuality"
    static let audioFormat = "audioFormat"
    static let selectedLanguage = "selectedLanguage"
    static let autoDetectLanguage = "autoDetectLanguage"
    static let transcriptionTask = "transcriptionTask"
    static let preferredModel = "preferredModel"
    static let computeUnits = "computeUnits"
    static let theme = "theme"
    static let showTimestamps = "showTimestamps"
}
