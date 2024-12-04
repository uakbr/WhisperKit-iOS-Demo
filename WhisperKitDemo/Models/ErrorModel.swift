//
// ErrorModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine

/// Model class representing error state and presentation
public class ErrorModel: ObservableObject {
    
    // MARK: - Properties
    
    private let errorManager: ErrorHandling
    private var subscriptions = Set<AnyCancellable>()
    
    @Published private(set) var currentError: WhisperKitError?
    @Published private(set) var errorHistory: [ErrorHistoryItem] = []
    @Published var showErrorAlert = false
    
    // MARK: - Initialization
    
    init(errorManager: ErrorHandling) {
        self.errorManager = errorManager
        setupSubscriptions()
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to error publisher
        errorManager.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &subscriptions)
    }
    
    private func handleError(_ error: WhisperKitError) {
        currentError = error
        showErrorAlert = true
        
        // Add to history
        let historyItem = ErrorHistoryItem(
            error: error,
            timestamp: Date()
        )
        errorHistory.append(historyItem)
        
        // Keep only last 100 errors
        if errorHistory.count > 100 {
            errorHistory.removeFirst(errorHistory.count - 100)
        }
    }
    
    // MARK: - Public Methods
    
    /// Dismisses the current error alert
    public func dismissError() {
        currentError = nil
        showErrorAlert = false
    }
    
    /// Clears the error history
    public func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    /// Gets errors that occurred within a specific time range
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of error history items within the range
    public func getErrors(from startDate: Date, to endDate: Date) -> [ErrorHistoryItem] {
        return errorHistory.filter { item in
            item.timestamp >= startDate && item.timestamp <= endDate
        }
    }
    
    /// Gets the count of errors by type
    /// - Returns: Dictionary mapping error types to their count
    public func getErrorCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        
        errorHistory.forEach { item in
            let errorType = String(describing: type(of: item.error))
            counts[errorType, default: 0] += 1
        }
        
        return counts
    }
}

/// Structure representing an item in the error history
public struct ErrorHistoryItem: Identifiable {
    public let id = UUID()
    public let error: WhisperKitError
    public let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
