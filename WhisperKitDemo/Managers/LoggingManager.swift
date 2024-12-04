//
// LoggingManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import os.log

/// Enum defining different log levels
public enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "\u{1F41E}" // bug
        case .info: return "\u{2139}" // information
        case .warning: return "\u{26A0}" // warning
        case .error: return "\u{274C}" // cross mark
        case .critical: return "\u{1F6A8}" // rotating light
        }
    }
}

/// Protocol defining logging capabilities
protocol Logging {
    func log(_ message: String, level: LogLevel, category: String?)
    func debug(_ message: String, category: String?)
    func info(_ message: String, category: String?)
    func warning(_ message: String, category: String?)
    func error(_ message: String, category: String?)
    func critical(_ message: String, category: String?)
}

/// Manager class responsible for centralized logging across the application
public final class LoggingManager: Logging {
    
    // MARK: - Properties
    
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.anthropic.whisperkit.demo"
    private var osLog: OSLog
    private let fileManager: FileManaging
    private let dateFormatter: DateFormatter
    private let logFileURL: URL
    
    #if DEBUG
    private var minimumLogLevel: LogLevel = .debug
    #else
    private var minimumLogLevel: LogLevel = .info
    #endif
    
    // MARK: - Initialization
    
    init(fileManager: FileManaging) {
        self.fileManager = fileManager
        self.osLog = OSLog(subsystem: subsystem, category: "default")
        
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Setup log file URL in the app's documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logFileURL = documentsPath.appendingPathComponent("whisperkit.log")
        
        setupLogFile()
    }
    
    // MARK: - Public Methods
    
    /// Logs a message with the specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level of the log
    ///   - category: Optional category for the log message
    public func log(_ message: String, level: LogLevel, category: String? = nil) {
        guard level.rawValue >= minimumLogLevel.rawValue else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let categoryStr = category.map { "[\($0)]" } ?? ""
        let formattedMessage = "\(timestamp) \(level.emoji) \(categoryStr) \(message)"
        
        // Log to console using OSLog
        os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
        
        // Log to file
        appendToLogFile(formattedMessage)
    }
    
    // MARK: - Convenience Methods
    
    public func debug(_ message: String, category: String? = nil) {
        log(message, level: .debug, category: category)
    }
    
    public func info(_ message: String, category: String? = nil) {
        log(message, level: .info, category: category)
    }
    
    public func warning(_ message: String, category: String? = nil) {
        log(message, level: .warning, category: category)
    }
    
    public func error(_ message: String, category: String? = nil) {
        log(message, level: .error, category: category)
    }
    
    public func critical(_ message: String, category: String? = nil) {
        log(message, level: .critical, category: category)
    }
    
    // MARK: - Private Methods
    
    private func setupLogFile() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // Rotate logs if file size exceeds 10MB
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            
            if fileSize > 10_000_000 { // 10MB
                try rotateLogFile()
            }
        } catch {
            os_log("Failed to setup log file: %{public}@", type: .error, error.localizedDescription)
        }
    }
    
    private func appendToLogFile(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }
    
    private func rotateLogFile() throws {
        let backupURL = logFileURL.deletingPathExtension().appendingPathExtension("old.log")
        
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        
        try FileManager.default.moveItem(at: logFileURL, to: backupURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
    
    // MARK: - Log Analytics
    
    /// Retrieves logs for a specific date range
    /// - Parameters:
    ///   - startDate: Start date for log retrieval
    ///   - endDate: End date for log retrieval
    /// - Returns: Array of log entries
    public func getLogs(from startDate: Date, to endDate: Date) throws -> [String] {
        guard let data = FileManager.default.contents(atPath: logFileURL.path),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        return content.components(separatedBy: .newlines)
            .filter { line in
                guard let dateStr = line.components(separatedBy: " ").first,
                      let date = dateFormatter.date(from: dateStr) else {
                    return false
                }
                return date >= startDate && date <= endDate
            }
    }
    
    /// Clears all logs
    public func clearLogs() throws {
        try FileManager.default.removeItem(at: logFileURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
}

// MARK: - Extensions

extension LoggingManager {
    /// Creates a scoped logger for a specific category
    /// - Parameter category: The category name for the scoped logger
    /// - Returns: A logging instance that automatically includes the category
    func scoped(for category: String) -> Logging {
        return ScopedLogger(logger: self, category: category)
    }
}

/// A wrapper class that provides scoped logging with a fixed category
private class ScopedLogger: Logging {
    private let logger: Logging
    private let category: String
    
    init(logger: Logging, category: String) {
        self.logger = logger
        self.category = category
    }
    
    func log(_ message: String, level: LogLevel, category: String?) {
        logger.log(message, level: level, category: self.category)
    }
    
    func debug(_ message: String, category: String?) {
        logger.debug(message, category: self.category)
    }
    
    func info(_ message: String, category: String?) {
        logger.info(message, category: self.category)
    }
    
    func warning(_ message: String, category: String?) {
        logger.warning(message, category: self.category)
    }
    
    func error(_ message: String, category: String?) {
        logger.error(message, category: self.category)
    }
    
    func critical(_ message: String, category: String?) {
        logger.critical(message, category: self.category)
    }
}
