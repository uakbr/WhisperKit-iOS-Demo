//
// ErrorView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for displaying error details and history
struct ErrorView: View {
    @ObservedObject var errorModel: ErrorModel
    @State private var selectedFilter = ErrorFilter.all
    @State private var searchText = ""
    
    private var filteredErrors: [ErrorHistoryItem] {
        var errors = errorModel.errorHistory
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .recent:
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            errors = errors.filter { $0.timestamp > lastDay }
        case .critical:
            errors = errors.filter { error in
                if case .critical = error.error {
                    return true
                }
                return false
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            errors = errors.filter { error in
                error.error.localizedDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return errors
    }
    
    var body: some View {
        List {
            Section {
                ForEach(filteredErrors) { item in
                    ErrorItemView(item: item)
                }
            } header: {
                if !filteredErrors.isEmpty {
                    Text("\(filteredErrors.count) Errors")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search errors")
        .navigationTitle("Error History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ErrorFilter.allCases) { filter in
                            Text(filter.rawValue)
                                .tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { errorModel.clearErrorHistory() }) {
                    Text("Clear")
                }
                .disabled(filteredErrors.isEmpty)
            }
        }
        .overlay {
            if filteredErrors.isEmpty {
                ContentUnavailableView(
                    "No Errors",
                    systemImage: "checkmark.circle",
                    description: Text(searchText.isEmpty
                                    ? "All clear! No errors to show."
                                    : "No errors matching your search.")
                )
            }
        }
    }
}

/// View for displaying a single error item
private struct ErrorItemView: View {
    let item: ErrorHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                errorIcon
                Text(errorType)
                    .font(.headline)
                Spacer()
                Text(item.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(item.error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let suggestion = item.error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var errorIcon: some View {
        Group {
            switch item.error {
            case .audioStreamError:
                Image(systemName: "waveform.slash")
                    .foregroundColor(.yellow)
            case .modelError:
                Image(systemName: "cpu")
                    .foregroundColor(.orange)
            case .transcriptionError:
                Image(systemName: "text.badge.xmark")
                    .foregroundColor(.red)
            case .storageError:
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundColor(.orange)
            case .networkError:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
            case .invalidConfiguration:
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.orange)
            case .resourceNotFound:
                Image(systemName: "questionmark.folder")
                    .foregroundColor(.yellow)
            case .unauthorized:
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
            case .unknown:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var errorType: String {
        switch item.error {
        case .audioStreamError: return "Audio Error"
        case .modelError: return "Model Error"
        case .transcriptionError: return "Transcription Error"
        case .storageError: return "Storage Error"
        case .networkError: return "Network Error"
        case .invalidConfiguration: return "Configuration Error"
        case .resourceNotFound: return "Resource Error"
        case .unauthorized: return "Authorization Error"
        case .unknown: return "Unknown Error"
        }
    }
}

// MARK: - Supporting Types

private enum ErrorFilter: String, Identifiable, CaseIterable {
    case all = "All Errors"
    case recent = "Last 24 Hours"
    case critical = "Critical Only"
    
    var id: Self { self }
}

#Preview {
    NavigationView {
        ErrorView(errorModel: PreviewMocks.errorModel)
    }
}
