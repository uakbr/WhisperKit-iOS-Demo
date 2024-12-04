//
// TranscriptionFormatter.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation

struct TranscriptionFormatter {
    static func format(_ transcription: TranscriptionResult) -> String {
        return formatText(transcription)
    }
    
    static func formatForExport(_ transcription: TranscriptionResult, includeMetadata: Bool = true) -> String {
        var output = ""
        
        if includeMetadata {
            output += "[Transcription Metadata]\n"
            output += "Date: \(formatDate(transcription.timestamp))\n"
            if let language = transcription.language {
                output += "Language: \(Locale.current.localizedString(forLanguageCode: language) ?? language)\n"
            }
            output += "Duration: \(formatDuration(transcription.duration))\n\n"
        }
        
        output += "[Transcription]\n"
        output += formatText(transcription)
        
        if includeMetadata && !transcription.segments.isEmpty {
            output += "\n\n[Segments]\n"
            for segment in transcription.segments {
                output += "\(formatDuration(segment.start)) -> \(formatDuration(segment.end)): "
                output += "\(segment.text) (\(Int(segment.probability * 100))% confidence)\n"
            }
        }
        
        return output
    }
    
    private static func formatText(_ transcription: TranscriptionResult) -> String {
        return transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
