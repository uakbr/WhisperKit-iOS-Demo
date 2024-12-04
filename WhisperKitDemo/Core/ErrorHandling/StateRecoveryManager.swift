import Foundation
import Combine

/// Restores application state after crashes or errors
class StateRecoveryManager {
    // MARK: - Properties through Private Methods remain the same as before...
    
    private func getCurrentState() throws -> AppState {
        // This should be implemented to capture current app state
        let state = AppState(
            timestamp: Date(),
            activeTranscriptionID: nil,
            settings: stateStorage.dictionaryRepresentation()
        )
        return state
    }
    
    private func listSavedStates() async throws -> [URL] {
        let contents = try await fileManager.listFiles(in: stateDirectory)
        return contents
            .filter { $0.pathExtension == "json" }
            .sorted { url1, url2 in
                let date1 = try? fileManager.getFileModificationDate(at: url1)
                let date2 = try? fileManager.getFileModificationDate(at: url2)
                return date1 ?? Date.distantPast > date2 ?? Date.distantPast
            }
    }
    
    private func loadState(from url: URL) async throws -> AppState {
        return try await fileManager.readJSON(from: url)
    }
    
    private func pruneOldStates() async throws {
        var states = try await listSavedStates()
        
        if states.count > maxStates {
            let statesToRemove = states[maxStates...]
            for stateURL in statesToRemove {
                try await fileManager.deleteFile(at: stateURL)
            }
        }
    }
    
    private func handleFrequentCrashes() {
        // Reset to default state
        stateStorage.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Clear saved states
        Task {
            let states = try? await listSavedStates()
            for stateURL in states ?? [] {
                try? await fileManager.deleteFile(at: stateURL)
            }
        }
        
        // Reset crash counter
        resetCrashCount()
        
        // Post notification for UI to show reset message
        NotificationCenter.default.post(
            name: .appStateReset,
            object: nil,
            userInfo: ["reason": "frequent_crashes"]
        )
    }
}

// MARK: - Supporting Types
struct AppState: Codable {
    let timestamp: Date
    let activeTranscriptionID: UUID?
    let settings: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case activeTranscriptionID
        case settings
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(activeTranscriptionID, forKey: .activeTranscriptionID)
        try container.encode(settings.jsonString, forKey: .settings)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        activeTranscriptionID = try container.decode(UUID?.self, forKey: .activeTranscriptionID)
        let settingsString = try container.decode(String.self, forKey: .settings)
        settings = settingsString.toDictionary() ?? [:]
    }
    
    init(timestamp: Date, activeTranscriptionID: UUID?, settings: [String: Any]) {
        self.timestamp = timestamp
        self.activeTranscriptionID = activeTranscriptionID
        self.settings = settings
    }
}

enum StateRecoveryError: Error {
    case initializationFailed
    case noSavedState
    case stateRestorationFailed
    case invalidStateData
    
    var localizedDescription: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize state recovery manager"
        case .noSavedState:
            return "No saved state available"
        case .stateRestorationFailed:
            return "Failed to restore application state"
        case .invalidStateData:
            return "Invalid state data format"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let appStateReset = Notification.Name("com.whisperkit.appStateReset")
}
