import Foundation
import WhisperKit

/// Mock objects for SwiftUI previews
struct PreviewMocks {
    static var transcriptionResult: TranscriptionResult {
        TranscriptionResult(
            text: "This is a sample transcription with multiple segments for testing purposes.",
            segments: [
                TranscriptionSegment(
                    id: 0,
                    text: "This is a sample transcription",
                    startTime: 0.0,
                    endTime: 2.5,
                    probability: 0.95
                ),
                TranscriptionSegment(
                    id: 1,
                    text: "with multiple segments",
                    startTime: 2.5,
                    endTime: 4.0,
                    probability: 0.92
                ),
                TranscriptionSegment(
                    id: 2,
                    text: "for testing purposes.",
                    startTime: 4.0,
                    endTime: 5.5,
                    probability: 0.88
                )
            ],
            audioURL: URL(string: "file:///mock/audio.m4a"),
            language: "en",
            duration: 5.5,
            timestamp: Date()
        )
    }

    // Keep existing dependency mocks...
    
    static var dependencies: DependencyContainer {
        DependencyContainer()
    }
    
    static var audioModel: AudioModel {
        dependencies.audioModel
    }
    
    static var transcriptionModel: TranscriptionModel {
        dependencies.transcriptionModel
    }
    
    static var settingsModel: SettingsModel {
        dependencies.settingsModel
    }
    
    static var errorModel: ErrorModel {
        dependencies.errorModel
    }
    
    static var modelManager: ModelManager {
        dependencies.modelManager
    }
    
    static var fileManager: FileManaging {
        MockFileManager()
    }
    
    static var errorManager: ErrorHandling {
        MockErrorManager()
    }
    
    static var logger: Logging {
        MockLogger()
    }
}