import Foundation
import Combine

/// Provides a unified interface for storing application data
class StorageManager {
    // MARK: - Properties
    private let fileManager = FileOperationsManager()
    private let cacheManager = CacheManager()
    private let backupManager = BackupManager()
    private let iCloudManager = iCloudSyncManager()
    
    // Storage paths
    private let documentsDirectory: URL
    private let cachesDirectory: URL
    private let transcriptionsDirectory: URL
    
    // MARK: - Initialization
    init() throws {
        // Set up storage directories
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageError.directorySetupFailed
        }
        documentsDirectory = documents
        
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw StorageError.directorySetupFailed
        }
        cachesDirectory = caches
        
        transcriptionsDirectory = documentsDirectory.appendingPathComponent("Transcriptions")
        
        try setupDirectories()
    }
    
    // MARK: - Public Methods
    func saveTranscription(_ transcription: TranscriptionData) async throws {
        let filename = transcription.id.uuidString + ".json"
        let fileURL = transcriptionsDirectory.appendingPathComponent(filename)
        
        // Save locally
        try await fileManager.writeJSON(transcription, to: fileURL)
        
        // Cache for quick access
        cacheManager.cache(transcription, forKey: transcription.id.uuidString)
        
        // Sync to iCloud if available
        try await iCloudManager.sync(fileURL)
        
        // Create backup
        try await backupManager.backup(fileURL)
    }
    
    func loadTranscription(id: UUID) async throws -> TranscriptionData {
        // Check cache first
        if let cached: TranscriptionData = cacheManager.get(forKey: id.uuidString) {
            return cached
        }
        
        // Load from file
        let filename = id.uuidString + ".json"
        let fileURL = transcriptionsDirectory.appendingPathComponent(filename)
        
        let transcription: TranscriptionData = try await fileManager.readJSON(from: fileURL)
        
        // Cache for future use
        cacheManager.cache(transcription, forKey: id.uuidString)
        
        return transcription
    }
    
    func deleteTranscription(id: UUID) async throws {
        let filename = id.uuidString + ".json"
        let fileURL = transcriptionsDirectory.appendingPathComponent(filename)
        
        // Remove from cache
        cacheManager.remove(forKey: id.uuidString)
        
        // Delete local file
        try await fileManager.deleteFile(at: fileURL)
        
        // Remove from iCloud
        try await iCloudManager.delete(fileURL)
        
        // Update backup
        try await backupManager.removeFromBackup(filename)
    }
    
    func listTranscriptions() async throws -> [TranscriptionMetadata] {
        let files = try await fileManager.listFiles(in: transcriptionsDirectory)
        
        return try await withThrowingTaskGroup(of: TranscriptionMetadata?.self) { group in
            for file in files where file.pathExtension == "json" {
                group.addTask {
                    if let transcription: TranscriptionData = try? await self.fileManager.readJSON(from: file) {
                        return TranscriptionMetadata(id: transcription.id,
                                                   timestamp: transcription.timestamp,
                                                   duration: transcription.duration)
                    }
                    return nil
                }
            }
            
            var metadata: [TranscriptionMetadata] = []
            for try await result in group {
                if let meta = result {
                    metadata.append(meta)
                }
            }
            
            return metadata.sorted(by: { $0.timestamp > $1.timestamp })
        }
    }
    
    func exportTranscription(_ id: UUID, to format: ExportFormat) async throws -> URL {
        let transcription = try await loadTranscription(id: id)
        let exportURL = try await ExportManager.shared.export(transcription, to: format)
        return exportURL
    }
    
    // MARK: - Private Methods
    private func setupDirectories() throws {
        try fileManager.createDirectory(at: transcriptionsDirectory)
    }
}

// MARK: - Supporting Types
struct TranscriptionData: Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let text: String
    let language: String
    let audioURL: URL?
    
    var metadata: TranscriptionMetadata {
        return TranscriptionMetadata(id: id, timestamp: timestamp, duration: duration)
    }
}

struct TranscriptionMetadata: Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
}

enum ExportFormat {
    case txt
    case json
    case srt
    case vtt
}

enum StorageError: Error {
    case directorySetupFailed
    case saveFailed
    case loadFailed
    case deleteFailed
    case exportFailed
    case invalidFormat
    
    var localizedDescription: String {
        switch self {
        case .directorySetupFailed:
            return "Failed to set up storage directories"
        case .saveFailed:
            return "Failed to save transcription"
        case .loadFailed:
            return "Failed to load transcription"
        case .deleteFailed:
            return "Failed to delete transcription"
        case .exportFailed:
            return "Failed to export transcription"
        case .invalidFormat:
            return "Invalid file format"
        }
    }
}
