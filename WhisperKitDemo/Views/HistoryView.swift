//
// HistoryView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for displaying transcription history
struct HistoryView: View {
    @ObservedObject var transcriptionModel: TranscriptionModel
    @State private var searchText = ""
    @State private var sortOrder = SortOrder.newest
    @State private var selectedTranscription: TranscriptionResult?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    
    private var filteredTranscriptions: [TranscriptionResult] {
        var results = transcriptionModel.transcriptions
        
        // Apply search filter
        if !searchText.isEmpty {
            results = results.filter { transcription in
                transcription.text.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sort order
        results.sort { first, second in
            switch sortOrder {
            case .newest:
                return first.timestamp > second.timestamp
            case .oldest:
                return first.timestamp < second.timestamp
            case .longest:
                return first.duration > second.duration
            case .shortest:
                return first.duration < second.duration
            }
        }
        
        return results
    }
    
    var body: some View {
        List {
            Section {
                ForEach(filteredTranscriptions) { transcription in
                    TranscriptionItemView(transcription: transcription)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTranscription = transcription
                        }
                        .contextMenu {
                            Button(action: { shareTranscription(transcription) }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive,
                                   action: { deleteTranscription(transcription) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                if !filteredTranscriptions.isEmpty {
                    Text("\(filteredTranscriptions.count) Transcriptions")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search transcriptions")
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue)
                                .tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
            }
        }
        .sheet(item: $selectedTranscription) { transcription in
            TranscriptionDetailView(transcription: transcription)
        }
        .sheet(isPresented: $showShareSheet, content: {
            if let transcription = selectedTranscription {
                ShareSheet(items: [transcription.text])
            }
        })
        .confirmationDialog(
            "Are you sure you want to delete this transcription?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let transcription = selectedTranscription {
                    transcriptionModel.deleteTranscription(id: transcription.id)
                }
            }
        }
        .overlay {
            if filteredTranscriptions.isEmpty {
                ContentUnavailableView(
                    "No Transcriptions",
                    systemImage: "text.bubble",
                    description: Text(searchText.isEmpty
                                    ? "Your transcription history will appear here."
                                    : "No transcriptions matching your search.")
                )
            }
        }
    }
    
    private func shareTranscription(_ transcription: TranscriptionResult) {
        selectedTranscription = transcription
        showShareSheet = true
    }
    
    private func deleteTranscription(_ transcription: TranscriptionResult) {
        selectedTranscription = transcription
        showDeleteConfirmation = true
    }
}

/// View for displaying a single transcription item
private struct TranscriptionItemView: View {
    let transcription: TranscriptionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let language = transcription.language {
                    Text(Locale.current.localizedString(forLanguageCode: language) ?? language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(formatDate(transcription.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Transcription Text
            Text(transcription.text)
                .lineLimit(3)
                .font(.body)
            
            // Footer
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatDuration(transcription.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today at " + DateFormatter.timeOnly.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday at " + DateFormatter.timeOnly.string(from: date)
        } else {
            return DateFormatter.dateAndTime.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// View for detailed transcription display
private struct TranscriptionDetailView: View {
    let transcription: TranscriptionResult
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        MetadataRow(title: "Language",
                                   value: transcription.language.map { Locale.current.localizedString(forLanguageCode: $0) ?? $0 } ?? "Unknown")
                        MetadataRow(title: "Duration",
                                   value: formatDuration(transcription.duration))
                        MetadataRow(title: "Created",
                                   value: formatDate(transcription.timestamp))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Segments
                    ForEach(transcription.segments) { segment in
                        SegmentView(segment: segment)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcription Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        return DateFormatter.dateAndTime.string(from: date)
    }
}

/// View for displaying metadata row
private struct MetadataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

/// View for displaying transcription segment
private struct SegmentView: View {
    let segment: TranscriptionSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(segment.text)
                .font(.body)
            
            HStack {
                Text(formatTimestamp(segment.start))
                Text("-")
                Text(formatTimestamp(segment.end))
                
                Spacer()
                
                Text("\(Int(segment.probability * 100))% confidence")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

private enum SortOrder: String, Identifiable, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case longest = "Longest First"
    case shortest = "Shortest First"
    
    var id: Self { self }
}

private extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    NavigationView {
        HistoryView(transcriptionModel: PreviewMocks.transcriptionModel)
    }
}
