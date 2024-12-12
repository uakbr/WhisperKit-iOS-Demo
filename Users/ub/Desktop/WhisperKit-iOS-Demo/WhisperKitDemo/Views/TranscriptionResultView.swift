import SwiftUI
import UIKit

/// View for displaying transcription results
struct TranscriptionResultView: View {
    // Keep existing implementation...
}

// Add ShareSheet struct
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TranscriptionResultView(
        transcription: PreviewMocks.transcriptionResult,
        audioModel: PreviewMocks.audioModel
    )
}