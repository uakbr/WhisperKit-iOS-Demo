//
// PreviewMocks.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation

/// Mock objects for SwiftUI previews
struct PreviewMocks {
    static var dependencies: DependencyContainer {
        DependencyContainer()
    }
    
    static var audioModel: AudioModel {
        dependencies.audioModel
    }
    
    static var transcriptionModel: TranscriptionModel {
        dependencies.transcriptionModel
    }
    
    static var settingsModel: SettingsModel {
        dependencies.settingsModel
    }
    
    static var errorModel: ErrorModel {
        dependencies.errorModel
    }
    
    static var modelManager: ModelManager {
        dependencies.modelManager
    }
    
    static var fileManager: FileManaging {
        MockFileManager()
    }
    
    static var errorManager: ErrorHandling {
        MockErrorManager()
    }
    
    static var logger: Logging {
        MockLogger()
    }
}

// MARK: - Mock Implementations

private class MockFileManager: FileManaging {
    func saveAudioFile(_ data: Data, fileName: String) throws -> URL {
        URL(fileURLWithPath: "/mock/audio/\(fileName)")
    }
    
    func loadAudioFile(at url: URL) throws -> Data {
        Data()
    }
    
    func deleteAudioFile(at url: URL) throws {}
    
    func listAudioFiles() throws -> [URL] {
        []
    }
    
    func saveTranscript(_ text: String, for audioURL: URL) throws -> URL {
        URL(fileURLWithPath: "/mock/transcripts/transcript.txt")
    }
    
    func loadTranscript(for audioURL: URL) throws -> String {
        ""
    }
    
    func saveModel(_ data: Data, name: String) throws -> URL {
        URL(fileURLWithPath: "/mock/models/\(name)")
    }
    
    func loadModel(name: String) throws -> Data {
        Data()
    }
    
    func deleteModel(name: String) throws {}
    
    func listModels() throws -> [String] {
        []
    }
}

private class MockErrorManager: ErrorHandling {
    func handle(_ error: WhisperKitError) {}
    
    func handle(_ error: WhisperKitError, recovery: @escaping () -> Void) {}
    
    func handleBackgroundError(_ error: WhisperKitError) {}
    
    var latestError: WhisperKitError? { nil }
    
    var errorPublisher: AnyPublisher<WhisperKitError, Never> {
        Empty().eraseToAnyPublisher()
    }
}

private class MockLogger: Logging {
    func log(_ message: String, level: LogLevel, category: String?) {}
    
    func debug(_ message: String, category: String?) {}
    
    func info(_ message: String, category: String?) {}
    
    func warning(_ message: String, category: String?) {}
    
    func error(_ message: String, category: String?) {}
    
    func critical(_ message: String, category: String?) {}
    
    func scoped(for category: String) -> Logging { self }
}
