import Foundation
import Combine

protocol ErrorHandling {
    func handle(_ error: WhisperKitError)
    func handle(_ error: WhisperKitError, recovery: @escaping () -> Void)
    func handleBackgroundError(_ error: WhisperKitError)
    var latestError: WhisperKitError? { get }
    var errorPublisher: AnyPublisher<WhisperKitError, Never> { get }
}

protocol StateRecoverable {
    func saveCurrentState()
    func restoreLastState() throws
    func resetToInitialState()
}

protocol ErrorRecoverable {
    func attemptRecovery(for error: WhisperKitError, with handler: @escaping () -> Void)
    func attemptAutomaticRecovery(for error: WhisperKitError)
    func attemptCriticalRecovery(for error: WhisperKitError, completion: @escaping (Bool) -> Void)
}