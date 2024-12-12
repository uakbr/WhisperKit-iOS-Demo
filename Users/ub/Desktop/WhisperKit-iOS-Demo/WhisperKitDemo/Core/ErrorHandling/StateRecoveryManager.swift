import Foundation

/// Restores application state after crashes or errors
class StateRecoveryManager {
    // MARK: - Properties
    private let stateDirectory: URL
    private let maxStates = 10
    private let fileManager = FileOperationsManager()
    private let stateStorage = UserDefaults.standard
    
    private var crashCount: Int {
        get { stateStorage.integer(forKey: "crash_count") }
        set { stateStorage.set(newValue, forKey: "crash_count") }
    }
    
    // MARK: - Initialization
    init() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        stateDirectory = documentsPath.appendingPathComponent("SavedStates")
        
        try fileManager.createDirectory(at: stateDirectory)
    }
    
    // MARK: - Public Methods
    func saveCurrentState() {
        Task {
            do {
                let state = try getCurrentState()
                let filename = "state_\(Date().timeIntervalSince1970).json"
                let fileURL = stateDirectory.appendingPathComponent(filename)
                
                try await fileManager.writeJSON(state, to: fileURL)
                try await pruneOldStates()
                
                // Reset crash count on successful save
                crashCount = 0
            } catch {
                crashCount += 1
                
                if crashCount >= 3 {
                    handleFrequentCrashes()
                }
            }
        }
    }
    
    func restoreLastState() {
        Task {
            do {
                let states = try await listSavedStates()
                if let latestState = states.first,
                   let state = try await loadState(from: latestState) {
                    try applyState(state)
                }
            } catch {
                // Error handling managed by ErrorManager
            }
        }
    }
    
    func resetToInitialState() {
        stateStorage.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        crashCount = 0
    }
    
    // Add getCurrentState() and other helper methods...
    
    private func applyState(_ state: AppState) throws {
        // Apply saved settings
        for (key, value) in state.settings {
            stateStorage.set(value, forKey: key)
        }
        
        // Notify observers of state restoration
        NotificationCenter.default.post(name: .appStateRestored, object: nil)
    }
    
    private func resetCrashCount() {
        crashCount = 0
        stateStorage.synchronize()
    }
}