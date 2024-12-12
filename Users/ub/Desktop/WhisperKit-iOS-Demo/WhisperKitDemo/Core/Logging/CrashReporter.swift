import Foundation
import UIKit

protocol CrashReporting {
    func log(_ error: Error)
    func logCriticalFailure(_ error: Error)
}

/// Reports and handles application crashes and critical errors
class CrashReporter: CrashReporting {
    private let logger: Logging
    private let deviceInfo: DeviceInfo
    private let crashLogDirectory: URL
    private let maxCrashLogs = 10
    
    init(logger: Logging? = nil) {
        self.logger = logger ?? LoggingManager(category: "CrashReporter")
        self.deviceInfo = DeviceInfo()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.crashLogDirectory = documentsPath.appendingPathComponent("CrashLogs")
        
        try? FileManager.default.createDirectory(at: crashLogDirectory, withIntermediateDirectories: true)
        setupCrashHandling()
    }
    
    func log(_ error: Error) {
        let report = generateErrorReport(error)
        saveCrashLog(report)
        logger.error(report)
    }
    
    func logCriticalFailure(_ error: Error) {
        let report = generateCrashReport(error)
        saveCrashLog(report)
        logger.critical(report)
    }
    
    private func setupCrashHandling() {
        NSSetUncaughtExceptionHandler { exception in
            let report = "Uncaught Exception: \(exception.name)\n"
                + "Reason: \(exception.reason ?? "Unknown")\n"
                + "Stack Trace:\n\(exception.callStackSymbols.joined(separator: "\n"))"
            
            self.saveCrashLog(report)
        }
    }
    
    private func saveCrashLog(_ report: String) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let filename = "crash_\(timestamp).log"
        let fileURL = crashLogDirectory.appendingPathComponent(filename)
        
        try? report.write(to: fileURL, atomically: true, encoding: .utf8)
        pruneCrashLogs()
    }
    
    private func pruneCrashLogs() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: crashLogDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        let sortedFiles = files.sorted { url1, url2 in
            let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
            let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
            return date1 ?? Date() > date2 ?? Date()
        }
        
        if sortedFiles.count > maxCrashLogs {
            let filesToDelete = Array(sortedFiles[maxCrashLogs...])
            for file in filesToDelete {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // Keep existing report generation methods...
}

// Add date formatter
private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
}