import UIKit
import Combine

/// Manages background task scheduling and execution
class BackgroundTaskManager {
    // MARK: - Properties
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimeRemaining: TimeInterval = 0
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onBackgroundTransition: (() -> Void)?
    var onBackgroundTimeUpdated: ((TimeInterval) -> Void)?
    var onBackgroundTaskExpiring: (() -> Void)?
    
    // Configuration
    private let minimumBackgroundTime: TimeInterval = 30.0
    private let warningThreshold: TimeInterval = 10.0
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
        
        startBackgroundTimeMonitoring()
    }
    
    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        stopBackgroundTimeMonitoring()
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    func requestAdditionalBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        
        // Start a new background task
        let newTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
        
        // End the old task
        UIApplication.shared.endBackgroundTask(backgroundTask)
        
        // Update tracking
        backgroundTask = newTask
        startBackgroundTimeMonitoring()
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func startBackgroundTimeMonitoring() {
        stopBackgroundTimeMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBackgroundTimeRemaining()
        }
    }
    
    private func stopBackgroundTimeMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateBackgroundTimeRemaining() {
        guard backgroundTask != .invalid else { return }
        
        backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
        onBackgroundTimeUpdated?(backgroundTimeRemaining)
        
        if backgroundTimeRemaining < warningThreshold {
            handleLowBackgroundTime()
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        onBackgroundTaskExpiring?()
        endBackgroundTask()
    }
    
    private func handleLowBackgroundTime() {
        // If we're running out of time but need more, request it
        if backgroundTimeRemaining < warningThreshold && needsAdditionalBackgroundTime() {
            requestAdditionalBackgroundTime()
        }
    }
    
    private func handleEnterBackground() {
        startBackgroundTask()
        onBackgroundTransition?()
    }
    
    private func handleEnterForeground() {
        endBackgroundTask()
    }
    
    private func needsAdditionalBackgroundTime() -> Bool {
        // Override this to implement custom logic for determining if more background time is needed
        return backgroundTimeRemaining < minimumBackgroundTime
    }
}

// MARK: - Background Task Error
enum BackgroundTaskError: Error {
    case taskCreationFailed
    case insufficientBackgroundTime
    
    var localizedDescription: String {
        switch self {
        case .taskCreationFailed:
            return "Failed to create background task"
        case .insufficientBackgroundTime:
            return "Insufficient background execution time"
        }
    }
}
