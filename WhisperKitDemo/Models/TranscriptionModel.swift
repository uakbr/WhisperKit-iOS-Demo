//
// TranscriptionModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine
import WhisperKit

/// Model class representing transcription state and history
public class TranscriptionModel: ObservableObject {
    
    // MARK: - Properties
    
    private let transcriptionManager: TranscriptionManaging
    private let fileManager: FileManaging
    private let errorManager: ErrorHandling
    private let logger: Logging
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var transcriptions: [TranscriptionResult] = []
    @Published private(set) var isTranscribing = false
    @Published private(set) var transcriptionProgress: Double = 0.0
    
    // MARK: - Initialization
    
    init(transcriptionManager: TranscriptionManaging,
         fileManager: FileManaging,
         errorManager: ErrorHandling,
         logger: Logging) {
        self.transcriptionManager = transcriptionManager
        self.fileManager = fileManager
        self.errorManager = errorManager
        self.logger = logger.scoped(for: "TranscriptionModel")
        
        setupSubscriptions()
        loadTranscriptionHistory()
    }
    
    // MARK: - Public Methods
    
    /// Transcribes an audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    public func transcribe(audioURL: URL) async {
        guard !isTranscribing else { return }
        
        isTranscribing = true
        transcriptionProgress = 0.0
        
        do {
            let result = try await transcriptionManager.transcribe(audioURL: audioURL)
            await MainActor.run {
                addTranscriptionResult(result)
            }
        } catch {
            errorManager.handle(.transcriptionError(error.localizedDescription))
        }
        
        isTranscribing = false
        transcriptionProgress = 0.0
    }
    
    /// Cancels the current transcription
    public func cancelTranscription() {
        transcriptionManager.cancelTranscription()
        isTranscribing = false
        transcriptionProgress = 0.0
    }
    
    /// Gets a transcription result by its ID
    /// - Parameter id: ID of the transcription result
    /// - Returns: The transcription result if found
    public func getTranscription(id: UUID) -> TranscriptionResult? {
        return transcriptions.first { $0.id == id }
    }
    
    /// Deletes a transcription result
    /// - Parameter id: ID of the transcription result to delete
    public func deleteTranscription(id: UUID) {
        guard let index = transcriptions.firstIndex(where: { $0.id == id }) else { return }
        
        let transcription = transcriptions[index]
        
        // Delete associated audio file if it exists
        if let audioURL = transcription.audioURL {
            do {
                try fileManager.deleteAudioFile(at: audioURL)
            } catch {
                logger.error("Failed to delete audio file: \(error.localizedDescription)")
            }
        }
        
        transcriptions.remove(at: index)
        saveTranscriptionHistory()
        
        logger.info("Deleted transcription with ID: \(id)")
    }
    
    /// Exports transcription results to JSON
    /// - Returns: JSON data containing transcription results
    public func exportTranscriptions() throws -> Data {
        return try JSONEncoder().encode(transcriptions)
    }
    
    /// Imports transcription results from JSON
    /// - Parameter data: JSON data containing transcription results
    public func importTranscriptions(_ data: Data) throws {
        let importedTranscriptions = try JSONDecoder().decode([TranscriptionResult].self, from: data)
        transcriptions.append(contentsOf: importedTranscriptions)
        saveTranscriptionHistory()
        
        logger.info("Imported \(importedTranscriptions.count) transcriptions")
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        transcriptionManager.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.transcriptionProgress = progress
            }
            .store(in: &cancellables)
    }
    
    private func addTranscriptionResult(_ result: TranscriptionResult) {
        transcriptions.append(result)
        saveTranscriptionHistory()
        
        logger.info("Added new transcription result with ID: \(result.id)")
    }
    
    private func loadTranscriptionHistory() {
        do {
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let historyURL = documentsURL.appendingPathComponent("transcription_history.json")
            
            guard FileManager.default.fileExists(atPath: historyURL.path) else { return }
            
            let data = try Data(contentsOf: historyURL)
            transcriptions = try JSONDecoder().decode([TranscriptionResult].self, from: data)
            
            logger.info("Loaded \(transcriptions.count) transcriptions from history")
        } catch {
            logger.error("Failed to load transcription history: \(error.localizedDescription)")
            errorManager.handle(.storageError("Failed to load transcription history"))
        }
    }
    
    private func saveTranscriptionHistory() {
        do {
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let historyURL = documentsURL.appendingPathComponent("transcription_history.json")
            
            let data = try JSONEncoder().encode(transcriptions)
            try data.write(to: historyURL)
            
            logger.info("Saved transcription history")
        } catch {
            logger.error("Failed to save transcription history: \(error.localizedDescription)")
            errorManager.handle(.storageError("Failed to save transcription history"))
        }
    }
}
