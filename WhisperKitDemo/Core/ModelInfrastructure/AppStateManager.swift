import Foundation
import Combine

/// Manages application state and provides seamless state recovery
class AppStateManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var currentState: AppState = .idle
    @Published private(set) var lastSavedState: SavedAppState?
    
    private let stateStorage: StateStorageManager
    private let backgroundTaskManager: BackgroundTaskManager
    private var cancellables = Set<AnyCancellable>()
    
    // State recovery settings
    private let autoSaveInterval: TimeInterval = 30.0 // 30 seconds
    private let maxSavedStates: Int = 5
    
    // MARK: - Initialization
    init(stateStorage: StateStorageManager = StateStorageManager(),
         backgroundTaskManager: BackgroundTaskManager = BackgroundTaskManager()) {
        self.stateStorage = stateStorage
        self.backgroundTaskManager = backgroundTaskManager
        
        setupStateMonitoring()
        setupBackgroundHandling()
    }
    
    // MARK: - Public Methods
    func transitionTo(_ newState: AppState) {
        let oldState = currentState
        currentState = newState
        
        // Handle state transition
        handleStateTransition(from: oldState, to: newState)
        
        // Auto-save state
        if shouldSaveState(newState) {
            saveCurrentState()
        }
    }
    
    func restoreLastState() async throws {
        guard let savedState = try await stateStorage.loadLatestState() else {
            throw StateError.noSavedState
        }
        
        try await restoreState(savedState)
    }
    
    func saveCurrentState() {
        let state = SavedAppState(
            timestamp: Date(),
            appState: currentState,
            modelState: captureModelState(),
            settings: UserDefaults.standard.dictionaryRepresentation()
        )
        
        Task {
            try await stateStorage.saveState(state)
            await MainActor.run { lastSavedState = state }
        }
    }
    
    // MARK: - Private Methods
    private func setupStateMonitoring() {
        // Monitor system notifications
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBackgrounding()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppTermination()
            }
            .store(in: &cancellables)
        
        // Set up auto-save timer
        Timer.publish(every: autoSaveInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.autoSaveState()
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundHandling() {
        backgroundTaskManager.onBackgroundTransition = { [weak self] in
            self?.saveCurrentState()
        }
    }
    
    private func handleStateTransition(from oldState: AppState, to newState: AppState) {
        switch newState {
        case .active:
            backgroundTaskManager.startBackgroundTask()
        case .background:
            backgroundTaskManager.endBackgroundTask()
        default:
            break
        }
    }
    
    private func shouldSaveState(_ state: AppState) -> Bool {
        switch state {
        case .active, .background:
            return true
        case .idle, .error:
            return false
        }
    }
    
    private func captureModelState() -> [String: Any] {
        // Capture relevant model state
        var modelState: [String: Any] = [:]
        
        // Add model-specific state capture here
        
        return modelState
    }
    
    private func autoSaveState() {
        guard shouldSaveState(currentState) else { return }
        saveCurrentState()
    }
    
    private func handleAppBackgrounding() {
        transitionTo(.background)
        saveCurrentState()
    }
    
    private func handleAppTermination() {
        saveCurrentState()
    }
    
    private func restoreState(_ savedState: SavedAppState) async throws {
        // Restore settings
        for (key, value) in savedState.settings {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // Restore model state
        try await restoreModelState(savedState.modelState)
        
        // Update current state
        await MainActor.run {
            currentState = savedState.appState
            lastSavedState = savedState
        }
    }
    
    private func restoreModelState(_ modelState: [String: Any]) async throws {
        // Implement model state restoration logic
    }
}

// MARK: - Supporting Types
enum AppState: Codable {
    case idle
    case active
    case background
    case error(String)
}

struct SavedAppState: Codable {
    let timestamp: Date
    let appState: AppState
    let modelState: [String: Any]
    let settings: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case appState
        case modelState
        case settings
    }
    
    // Custom encoding/decoding for Any type
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(appState, forKey: .appState)
        try container.encode(modelState.jsonString, forKey: .modelState)
        try container.encode(settings.jsonString, forKey: .settings)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appState = try container.decode(AppState.self, forKey: .appState)
        let modelStateString = try container.decode(String.self, forKey: .modelState)
        let settingsString = try container.decode(String.self, forKey: .settings)
        
        modelState = modelStateString.toDictionary() ?? [:]
        settings = settingsString.toDictionary() ?? [:]
    }
    
    init(timestamp: Date, appState: AppState, modelState: [String: Any], settings: [String: Any]) {
        self.timestamp = timestamp
        self.appState = appState
        self.modelState = modelState
        self.settings = settings
    }
}

// MARK: - Error Types
enum StateError: Error {
    case noSavedState
    case stateRestorationFailed
    case invalidStateData
    
    var localizedDescription: String {
        switch self {
        case .noSavedState:
            return "No saved state available"
        case .stateRestorationFailed:
            return "Failed to restore application state"
        case .invalidStateData:
            return "Invalid state data format"
        }
    }
}

// MARK: - Extensions
extension Dictionary where Key == String {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

extension String {
    func toDictionary() -> [String: Any]? {
        guard let data = self.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
