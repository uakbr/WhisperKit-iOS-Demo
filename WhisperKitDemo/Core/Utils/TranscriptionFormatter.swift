import Foundation

/// Formats transcriptions for presentation and storage
class TranscriptionFormatter {
    // MARK: - Properties
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    // MARK: - Public Methods
    func formatTranscriptionForDisplay(_ transcription: TranscriptionData) -> FormattedTranscription {
        return FormattedTranscription(
            id: transcription.id,
            title: generateTitle(for: transcription),
            formattedDate: formatDate(transcription.timestamp),
            formattedDuration: formatDuration(transcription.duration),
            text: formatText(transcription.text),
            language: formatLanguage(transcription.language),
            segments: formatSegments(transcription.segments)
        )
    }
    
    func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let components = DateComponentsFormatter()
        components.allowedUnits = [.minute, .second]
        components.zeroFormattingBehavior = .pad
        return components.string(from: timestamp) ?? "00:00"
    }
    
    func formatSegmentTimestamp(_ timestamp: TimeInterval) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        let milliseconds = Int((timestamp.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    func formatLanguage(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
    
    // MARK: - Private Methods
    private func generateTitle(for transcription: TranscriptionData) -> String {
        let date = formatDate(transcription.timestamp, style: .short)
        let preview = transcription.text.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(date) - \(preview)..."
    }
    
    private func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        return durationFormatter.string(from: duration) ?? "0s"
    }
    
    private func formatText(_ text: String) -> String {
        // Apply text formatting rules
        var formattedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\s+", with: " ", options: .regularExpression)
        
        // Ensure proper capitalization
        if !formattedText.isEmpty {
            formattedText = formattedText.prefix(1).uppercased() + formattedText.dropFirst()
        }
        
        // Ensure proper punctuation
        if !formattedText.isEmpty && !".,!?".contains(formattedText.last!) {
            formattedText += "."
        }
        
        return formattedText
    }
    
    private func formatSegments(_ segments: [TranscriptionSegment]?) -> [FormattedSegment] {
        return segments?.map { segment in
            FormattedSegment(
                id: segment.id,
                startTime: formatSegmentTimestamp(segment.startTime),
                endTime: formatSegmentTimestamp(segment.endTime),
                text: formatText(segment.text),
                confidence: formatConfidence(segment.confidence)
            )
        } ?? []
    }
    
    private func formatConfidence(_ confidence: Float) -> String {
        return String(format: "%.1f%%", confidence * 100)
    }
}

// MARK: - Supporting Types
struct FormattedTranscription: Identifiable {
    let id: UUID
    let title: String
    let formattedDate: String
    let formattedDuration: String
    let text: String
    let language: String
    let segments: [FormattedSegment]
}

struct FormattedSegment: Identifiable {
    let id: UUID
    let startTime: String
    let endTime: String
    let text: String
    let confidence: String
}

struct TranscriptionSegment: Identifiable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Float
}

// MARK: - Extension Methods
extension TranscriptionData {
    var formattedText: String {
        return TranscriptionFormatter().formatText(text)
    }
    
    var formattedDuration: String {
        return TranscriptionFormatter().formatDuration(duration)
    }
    
    var formattedDate: String {
        return TranscriptionFormatter().formatDate(timestamp)
    }
}
