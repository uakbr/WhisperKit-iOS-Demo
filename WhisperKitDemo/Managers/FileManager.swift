//
// FileManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine

/// Protocol defining the file management capabilities required by the FileManager
protocol FileManaging {
    func saveAudioFile(_ data: Data, fileName: String) throws -> URL
    func loadAudioFile(at url: URL) throws -> Data
    func deleteAudioFile(at url: URL) throws
    func listAudioFiles() throws -> [URL]
    func saveTranscript(_ text: String, for audioURL: URL) throws -> URL
    func loadTranscript(for audioURL: URL) throws -> String
    func saveModel(_ data: Data, name: String) throws -> URL
    func loadModel(name: String) throws -> Data
    func deleteModel(name: String) throws
    func listModels() throws -> [String]
}

/// Manager class responsible for handling all file operations in the application
public final class AudioFileManager: FileManaging {
    
    // MARK: - Properties
    
    private let fileManager = Foundation.FileManager.default
    private let errorManager: ErrorHandling
    
    // Directory URLs
    private lazy var audioDirectory: URL = {
        try! applicationDirectory().appendingPathComponent("Audio", isDirectory: true)
    }()
    
    private lazy var transcriptsDirectory: URL = {
        try! applicationDirectory().appendingPathComponent("Transcripts", isDirectory: true)
    }()
    
    private lazy var modelsDirectory: URL = {
        try! applicationDirectory().appendingPathComponent("Models", isDirectory: true)
    }()
    
    // MARK: - Initialization
    
    init(errorManager: ErrorHandling) {
        self.errorManager = errorManager
        setupDirectories()
    }
    
    // MARK: - Public Methods - Audio Files
    
    /// Saves audio data to a file
    /// - Parameters:
    ///   - data: The audio data to save
    ///   - fileName: Name for the audio file
    /// - Returns: URL of the saved file
    public func saveAudioFile(_ data: Data, fileName: String) throws -> URL {
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Loads audio data from a file
    /// - Parameter url: URL of the audio file
    /// - Returns: The audio data
    public func loadAudioFile(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
    
    /// Deletes an audio file
    /// - Parameter url: URL of the audio file to delete
    public func deleteAudioFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    /// Lists all audio files in the audio directory
    /// - Returns: Array of audio file URLs
    public func listAudioFiles() throws -> [URL] {
        try fileManager.contentsOfDirectory(at: audioDirectory,
                                          includingPropertiesForKeys: nil,
                                          options: .skipsHiddenFiles)
    }
    
    // MARK: - Public Methods - Transcripts
    
    /// Saves a transcript for an audio file
    /// - Parameters:
    ///   - text: The transcript text
    ///   - audioURL: URL of the corresponding audio file
    /// - Returns: URL of the saved transcript
    public func saveTranscript(_ text: String, for audioURL: URL) throws -> URL {
        let fileName = audioURL.deletingPathExtension().lastPathComponent + ".txt"
        let transcriptURL = transcriptsDirectory.appendingPathComponent(fileName)
        try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
        return transcriptURL
    }
    
    /// Loads a transcript for an audio file
    /// - Parameter audioURL: URL of the corresponding audio file
    /// - Returns: The transcript text
    public func loadTranscript(for audioURL: URL) throws -> String {
        let fileName = audioURL.deletingPathExtension().lastPathComponent + ".txt"
        let transcriptURL = transcriptsDirectory.appendingPathComponent(fileName)
        return try String(contentsOf: transcriptURL, encoding: .utf8)
    }
    
    // MARK: - Public Methods - Models
    
    /// Saves model data
    /// - Parameters:
    ///   - data: The model data to save
    ///   - name: Name of the model
    /// - Returns: URL of the saved model
    public func saveModel(_ data: Data, name: String) throws -> URL {
        let fileURL = modelsDirectory.appendingPathComponent(name)
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Loads model data
    /// - Parameter name: Name of the model
    /// - Returns: The model data
    public func loadModel(name: String) throws -> Data {
        let fileURL = modelsDirectory.appendingPathComponent(name)
        return try Data(contentsOf: fileURL)
    }
    
    /// Deletes a model
    /// - Parameter name: Name of the model to delete
    public func deleteModel(name: String) throws {
        let fileURL = modelsDirectory.appendingPathComponent(name)
        try fileManager.removeItem(at: fileURL)
    }
    
    /// Lists all available models
    /// - Returns: Array of model names
    public func listModels() throws -> [String] {
        try fileManager.contentsOfDirectory(at: modelsDirectory,
                                          includingPropertiesForKeys: nil,
                                          options: .skipsHiddenFiles)
            .map { $0.lastPathComponent }
    }
    
    // MARK: - Private Methods
    
    private func applicationDirectory() throws -> URL {
        try fileManager.url(for: .applicationSupportDirectory,
                           in: .userDomainMask,
                           appropriateFor: nil,
                           create: true)
    }
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: audioDirectory,
                                          withIntermediateDirectories: true)
            try fileManager.createDirectory(at: transcriptsDirectory,
                                          withIntermediateDirectories: true)
            try fileManager.createDirectory(at: modelsDirectory,
                                          withIntermediateDirectories: true)
        } catch {
            errorManager.handle(.storageError("Failed to create application directories: \(error.localizedDescription)"))
        }
    }
}

// MARK: - Extensions

extension AudioFileManager {
    /// Generates a unique filename with timestamp
    static func generateUniqueFileName(extension: String = "m4a") -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "recording_\(timestamp).\(`extension`)"
    }
    
    /// Checks if a file exists at the given URL
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    /// Gets the size of a file in bytes
    func fileSize(at url: URL) throws -> UInt64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }
}
