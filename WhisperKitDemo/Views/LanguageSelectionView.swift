//
// LanguageSelectionView.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import SwiftUI

/// View for selecting transcription language
struct LanguageSelectionView: View {
    @ObservedObject var settingsModel: SettingsModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private let languages = WhisperKit.supportedLanguages
        .sorted { first, second in
            let firstLocal = Locale.current.localizedString(forLanguageCode: first) ?? first
            let secondLocal = Locale.current.localizedString(forLanguageCode: second) ?? second
            return firstLocal < secondLocal
        }
    
    private var filteredLanguages: [String] {
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { language in
                let localizedName = Locale.current.localizedString(forLanguageCode: language) ?? language
                return localizedName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Auto-detect option
                Section {
                    Toggle(isOn: $settingsModel.autoDetectLanguage) {
                        VStack(alignment: .leading) {
                            Text("Auto-detect Language")
                                .font(.headline)
                            Text("Let WhisperKit determine the spoken language")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Language list
                Section {
                    ForEach(filteredLanguages, id: \.self) { language in
                        LanguageRowView(
                            language: language,
                            isSelected: !settingsModel.autoDetectLanguage && settingsModel.selectedLanguage == language
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            settingsModel.selectedLanguage = language
                            settingsModel.autoDetectLanguage = false
                            dismiss()
                        }
                    }
                } header: {
                    if !filteredLanguages.isEmpty {
                        Text("\(filteredLanguages.count) Languages")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if filteredLanguages.isEmpty {
                    ContentUnavailableView(
                        "No Languages Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                }
            }
        }
    }
}

/// View for displaying a language row
private struct LanguageRowView: View {
    let language: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(Locale.current.localizedString(forLanguageCode: language) ?? language)
                    .font(.body)
                
                Text(language.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    LanguageSelectionView(settingsModel: PreviewMocks.settingsModel)
}
