//
// ErrorManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine

/// Enumeration of all possible error types in the application
public enum WhisperKitError: LocalizedError {
    case audioStreamError(String)
    case modelError(String)
    case transcriptionError(String)
    case storageError(String)
    case networkError(String)
    case invalidConfiguration(String)
    case resourceNotFound(String)
    case unauthorized(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .audioStreamError(let message): return "Audio Stream Error: \(message)"
        case .modelError(let message): return "Model Error: \(message)"
        case .transcriptionError(let message): return "Transcription Error: \(message)"
        case .storageError(let message): return "Storage Error: \(message)"
        case .networkError(let message): return "Network Error: \(message)"
        case .invalidConfiguration(let message): return "Configuration Error: \(message)"
        case .resourceNotFound(let message): return "Resource Not Found: \(message)"
        case .unauthorized(let message): return "Authorization Error: \(message)"
        case .unknown(let message): return "Unknown Error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .audioStreamError(_):
            return "Try restarting the audio session or checking microphone permissions."
        case .modelError(_):
            return "Try redownloading the model or freeing up device storage."
        case .transcriptionError(_):
            return "Try restarting the transcription or checking audio input quality."
        case .storageError(_):
            return "Check available storage space or try clearing cached data."
        case .networkError(_):
            return "Check your internet connection and try again."
        case .invalidConfiguration(_):
            return "Reset to default settings or check configuration values."
        case .resourceNotFound(_):
            return "Try redownloading required resources or reinstalling the app."
        case .unauthorized(_):
            return "Check app permissions or try signing in again."
        case .unknown(_):
            return "Try restarting the app or contact support if the issue persists."
        }
    }
}

/// Protocol defining the error handling capabilities required by the ErrorManager
protocol ErrorHandling {
    func handle(_ error: WhisperKitError)
    func handle(_ error: WhisperKitError, recovery: @escaping () -> Void)
    func handleBackgroundError(_ error: WhisperKitError)
    var latestError: WhisperKitError? { get }
    var errorPublisher: AnyPublisher<WhisperKitError, Never> { get }
}

/// Manager class responsible for centralized error handling across the application
public final class ErrorManager: ErrorHandling {
    
    // MARK: - Properties
    
    private let errorSubject = PassthroughSubject<WhisperKitError, Never>()
    private var errorRecoveryManager: ErrorRecoveryManager
    private var stateRecoveryManager: StateRecoveryManager
    private var crashReporter: CrashReporter
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var latestError: WhisperKitError?
    
    // MARK: - Public Interface
    
    var errorPublisher: AnyPublisher<WhisperKitError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(errorRecoveryManager: ErrorRecoveryManager,
         stateRecoveryManager: StateRecoveryManager,
         crashReporter: CrashReporter) {
        self.errorRecoveryManager = errorRecoveryManager
        self.stateRecoveryManager = stateRecoveryManager
        self.crashReporter = crashReporter
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Handles an error with optional recovery action
    /// - Parameters:
    ///   - error: The error to handle
    ///   - recovery: Optional closure containing recovery logic
    public func handle(_ error: WhisperKitError, recovery: @escaping () -> Void) {
        errorSubject.send(error)
        latestError = error
        
        // Log error
        logError(error)
        
        // Attempt recovery if provided
        if shouldAttemptRecovery(for: error) {
            errorRecoveryManager.attemptRecovery(for: error, with: recovery)
        }
    }
    
    /// Handles an error without recovery action
    /// - Parameter error: The error to handle
    public func handle(_ error: WhisperKitError) {
        handle(error) {}
    }
    
    /// Handles errors that occur in background tasks
    /// - Parameter error: The error to handle
    public func handleBackgroundError(_ error: WhisperKitError) {
        // Log error but don't show UI
        logError(error)
        
        // Attempt automatic recovery if possible
        if shouldAttemptRecovery(for: error) {
            errorRecoveryManager.attemptAutomaticRecovery(for: error)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Monitor for critical errors that require state recovery
        errorSubject
            .filter { [weak self] error in
                self?.isCriticalError(error) ?? false
            }
            .sink { [weak self] error in
                self?.handleCriticalError(error)
            }
            .store(in: &cancellables)
    }
    
    private func logError(_ error: WhisperKitError) {
        #if DEBUG
        print("[ERROR] \(error.localizedDescription)")
        #endif
        
        crashReporter.log(error)
    }
    
    private func shouldAttemptRecovery(for error: WhisperKitError) -> Bool {
        switch error {
        case .unknown,
             .invalidConfiguration:
            return false
        default:
            return true
        }
    }
    
    private func isCriticalError(_ error: WhisperKitError) -> Bool {
        switch error {
        case .modelError,
             .storageError,
             .invalidConfiguration:
            return true
        default:
            return false
        }
    }
    
    private func handleCriticalError(_ error: WhisperKitError) {
        // Save current state before attempting recovery
        stateRecoveryManager.saveCurrentState()
        
        // Attempt to recover from critical error
        errorRecoveryManager.attemptCriticalRecovery(for: error) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // If recovery successful, restore saved state
                self.stateRecoveryManager.restoreLastState()
            } else {
                // If recovery failed, reset to initial state
                self.stateRecoveryManager.resetToInitialState()
                
                // Log critical failure
                self.crashReporter.logCriticalFailure(error)
            }
        }
    }
}

// MARK: - Extensions

extension ErrorManager {
    /// Convenience method to create an error with a custom message
    static func createError(_ type: WhisperKitError, message: String) -> WhisperKitError {
        switch type {
        case .audioStreamError(_): return .audioStreamError(message)
        case .modelError(_): return .modelError(message)
        case .transcriptionError(_): return .transcriptionError(message)
        case .storageError(_): return .storageError(message)
        case .networkError(_): return .networkError(message)
        case .invalidConfiguration(_): return .invalidConfiguration(message)
        case .resourceNotFound(_): return .resourceNotFound(message)
        case .unauthorized(_): return .unauthorized(message)
        case .unknown(_): return .unknown(message)
        }
    }
    
    /// Convenience method to wrap throwing functions with error handling
    func withErrorHandling<T>(_ operation: () throws -> T) -> T? {
        do {
            return try operation()
        } catch {
            handle(.unknown(error.localizedDescription))
            return nil
        }
    }
    
    /// Convenience method to wrap async throwing functions with error handling
    func withErrorHandling<T>(_ operation: () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            handle(.unknown(error.localizedDescription))
            return nil
        }
    }
}
