import Foundation

/// Manages the export of transcription data into various formats
class ExportManager {
    // MARK: - Properties
    static let shared = ExportManager()
    private let fileManager = FileOperationsManager()
    
    // Export configuration
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    // MARK: - Public Methods
    func export(_ transcription: TranscriptionData, to format: ExportFormat) async throws -> URL {
        let exportDirectory = try getExportDirectory()
        let filename = generateFilename(for: transcription, format: format)
        let exportURL = exportDirectory.appendingPathComponent(filename)
        
        let exportData = try formatTranscription(transcription, to: format)
        
        do {
            try exportData.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            throw ExportError.writeFailed(error)
        }
    }
    
    func exportBatch(_ transcriptions: [TranscriptionData], to format: ExportFormat) async throws -> URL {
        let exportDirectory = try getExportDirectory()
        let filename = "transcriptions_\(Date().timeIntervalSince1970).\(format.extension)"
        let exportURL = exportDirectory.appendingPathComponent(filename)
        
        var exportContent = ""
        
        switch format {
        case .txt:
            exportContent = transcriptions
                .map { formatTranscriptionAsText($0) }
                .joined(separator: "\n\n---\n\n")
            
        case .json:
            let jsonData = try JSONEncoder().encode(transcriptions)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                exportContent = jsonString
            }
            
        case .srt:
            exportContent = transcriptions
                .map { formatTranscriptionAsSRT($0) }
                .joined(separator: "\n\n")
            
        case .vtt:
            exportContent = "WEBVTT\n\n" + transcriptions
                .map { formatTranscriptionAsVTT($0) }
                .joined(separator: "\n\n")
        }
        
        do {
            try exportContent.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            throw ExportError.writeFailed(error)
        }
    }
    
    // MARK: - Private Methods
    private func getExportDirectory() throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDirectory = documentsDirectory.appendingPathComponent("Exports")
        
        try fileManager.createDirectory(at: exportDirectory)
        return exportDirectory
    }
    
    private func generateFilename(for transcription: TranscriptionData, format: ExportFormat) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "transcription_\(transcription.id.uuidString)_\(timestamp).\(format.extension)"
    }
    
    private func formatTranscription(_ transcription: TranscriptionData, to format: ExportFormat) throws -> String {
        switch format {
        case .txt:
            return formatTranscriptionAsText(transcription)
        case .json:
            return try formatTranscriptionAsJSON(transcription)
        case .srt:
            return formatTranscriptionAsSRT(transcription)
        case .vtt:
            return formatTranscriptionAsVTT(transcription)
        }
    }
    
    private func formatTranscriptionAsText(_ transcription: TranscriptionData) -> String {
        return """
        Transcription Date: \(dateFormatter.string(from: transcription.timestamp))
        Duration: \(formatDuration(transcription.duration))
        Language: \(transcription.language)
        
        Text:
        \(transcription.text)
        """
    }
    
    private func formatTranscriptionAsJSON(_ transcription: TranscriptionData) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(transcription)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ExportError.formattingFailed
        }
        
        return jsonString
    }
    
    private func formatTranscriptionAsSRT(_ transcription: TranscriptionData) -> String {
        // This is a placeholder - actual implementation would parse timestamps and segments
        return """
        1
        00:00:00,000 --> \(formatSRTTimestamp(transcription.duration))
        \(transcription.text)
        """
    }
    
    private func formatTranscriptionAsVTT(_ transcription: TranscriptionData) -> String {
        // This is a placeholder - actual implementation would parse timestamps and segments
        return """
        00:00.000 --> \(formatVTTTimestamp(transcription.duration))
        \(transcription.text)
        """
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatSRTTimestamp(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    private func formatVTTTimestamp(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - Supporting Types
extension ExportFormat {
    var `extension`: String {
        switch self {
        case .txt:
            return "txt"
        case .json:
            return "json"
        case .srt:
            return "srt"
        case .vtt:
            return "vtt"
        }
    }
}

enum ExportError: Error {
    case writeFailed(Error)
    case formattingFailed
    case invalidFormat
    
    var localizedDescription: String {
        switch self {
        case .writeFailed(let error):
            return "Failed to write export file: \(error.localizedDescription)"
        case .formattingFailed:
            return "Failed to format transcription data"
        case .invalidFormat:
            return "Invalid export format"
        }
    }
}
