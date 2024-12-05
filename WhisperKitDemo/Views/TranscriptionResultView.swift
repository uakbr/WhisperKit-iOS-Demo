import SwiftUI

/// View for displaying transcription results
struct TranscriptionResultView: View {
    let transcription: TranscriptionResult
    @ObservedObject var audioModel: AudioModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSegmentId: UUID?
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata Section
                HStack {
                    if let language = transcription.language {
                        Label(
                            Locale.current.localizedString(forLanguageCode: language) ?? language,
                            systemImage: "globe"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatDuration(transcription.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                // Full Text Section
                Text(transcription.text)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Segments Section
                ForEach(transcription.segments) { segment in
                    SegmentView(
                        segment: segment,
                        isSelected: selectedSegmentId == segment.id,
                        onTap: { seekToSegment(segment) }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [transcription.text])
        }
    }
    
    private func seekToSegment(_ segment: TranscriptionSegment) {
        selectedSegmentId = segment.id
        audioModel.seek(to: segment.start)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct SegmentView: View {
    let segment: TranscriptionSegment
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formatTimestamp(segment.start))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("-")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(formatTimestamp(segment.end))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(segment.probability * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(segment.text)
                    .font(.body)
                    .padding(.top, 2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
struct TranscriptionResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TranscriptionResultView(
                transcription: PreviewMocks.transcriptionResult,
                audioModel: PreviewMocks.audioModel
            )
        }
    }
}
#endif
