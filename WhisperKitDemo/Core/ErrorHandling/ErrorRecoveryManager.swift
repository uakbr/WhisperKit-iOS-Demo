import Foundation
import Combine

/// Handles non-critical errors with retry mechanisms
class ErrorRecoveryManager {
    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.whisperkit.errorrecovery", qos: .utility)
    private var recoveryHandlers: [String: ErrorRecoveryHandler] = [:]
    private var currentRetryCount: [String: Int] = [:]
    
    // Configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Error tracking
    @Published private(set) var activeErrors: [RecoverableError] = []
    
    // MARK: - Public Methods
    func registerRecoveryHandler<T>(
        for errorType: T.Type,
        identifier: String,
        handler: @escaping (Error) async throws -> Void
    ) {
        recoveryHandlers[identifier] = ErrorRecoveryHandler(handler: handler)
    }
    
    func handleError(_ error: Error, identifier: String) async throws {
        // Check if we have a handler for this error type
        guard let handler = recoveryHandlers[identifier] else {
            throw ErrorRecoveryError.noHandlerRegistered
        }
        
        // Get current retry count
        let retryCount = currentRetryCount[identifier] ?? 0
        
        // Check if we've exceeded max retries
        guard retryCount < maxRetryAttempts else {
            currentRetryCount[identifier] = 0
            throw ErrorRecoveryError.maxRetriesExceeded
        }
        
        // Create recoverable error
        let recoverableError = RecoverableError(
            error: error,
            identifier: identifier,
            retryCount: retryCount
        )
        
        // Add to active errors
        await MainActor.run {
            activeErrors.append(recoverableError)
        }
        
        do {
            // Calculate retry delay using exponential backoff
            let delay = calculateRetryDelay(for: retryCount)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Attempt recovery
            try await handler.handle(error)
            
            // Recovery succeeded
            currentRetryCount[identifier] = 0
            await removeActiveError(recoverableError)
        } catch {
            // Increment retry count
            currentRetryCount[identifier] = retryCount + 1
            
            // If we haven't exceeded max retries, try again
            if retryCount + 1 < maxRetryAttempts {
                try await handleError(error, identifier: identifier)
            } else {
                await removeActiveError(recoverableError)
                throw ErrorRecoveryError.recoveryFailed(error)
            }
        }
    }
    
    func clearRetryCount(for identifier: String) {
        currentRetryCount[identifier] = 0
    }
    
    func clearAllRetryCounters() {
        currentRetryCount.removeAll()
    }
    
    // MARK: - Private Methods
    private func calculateRetryDelay(for attempt: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...(exponentialDelay * 0.1))
        return exponentialDelay + jitter
    }
    
    @MainActor
    private func removeActiveError(_ error: RecoverableError) {
        activeErrors.removeAll { $0.identifier == error.identifier }
    }
}

// MARK: - Supporting Types
struct ErrorRecoveryHandler {
    let handle: (Error) async throws -> Void
}

struct RecoverableError: Identifiable {
    let id = UUID()
    let error: Error
    let identifier: String
    let retryCount: Int
    let timestamp = Date()
}

enum ErrorRecoveryError: Error {
    case noHandlerRegistered
    case maxRetriesExceeded
    case recoveryFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .noHandlerRegistered:
            return "No error recovery handler registered"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .recoveryFailed(let error):
            return "Error recovery failed: \(error.localizedDescription)"
        }
    }
}
