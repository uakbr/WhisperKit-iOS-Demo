import Foundation
import Combine

/// Handles backup creation and restoration of app data
class BackupManager {
    // MARK: - Properties
    private let fileManager = FileOperationsManager()
    private let queue = DispatchQueue(label: "com.whisperkit.backup", qos: .utility)
    
    private let backupDirectory: URL
    private let maxBackupCount = 5
    
    // Backup configuration
    private let backupInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    private var lastBackupDate: Date?
    
    // MARK: - Initialization
    init() throws {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BackupError.initializationFailed
        }
        
        backupDirectory = documents.appendingPathComponent("Backups")
        try fileManager.createDirectory(at: backupDirectory)
        
        setupBackupSchedule()
    }
    
    // MARK: - Public Methods
    func backup(_ fileURL: URL) async throws {
        guard shouldPerformBackup() else { return }
        
        // Create backup directory for current date
        let backupDate = Date()
        let dateFormatter = ISO8601DateFormatter()
        let backupName = dateFormatter.string(from: backupDate)
        
        let backupPath = backupDirectory.appendingPathComponent(backupName)
        try fileManager.createDirectory(at: backupPath)
        
        // Copy file to backup
        let destinationURL = backupPath.appendingPathComponent(fileURL.lastPathComponent)
        try await fileManager.copyFile(from: fileURL, to: destinationURL)
        
        // Update backup metadata
        lastBackupDate = backupDate
        try await pruneOldBackups()
    }
    
    func restoreFromLatestBackup() async throws {
        // Get sorted list of backups
        let backups = try await listBackups()
        guard let latestBackup = backups.first else {
            throw BackupError.noBackupsAvailable
        }
        
        try await restoreFromBackup(latestBackup)
    }
    
    func restoreFromBackup(_ backupURL: URL) async throws {
        let contents = try await fileManager.listFiles(in: backupURL)
        
        // Restore each file
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            
            try await fileManager.copyFile(from: fileURL, to: destinationURL)
        }
    }
    
    func removeFromBackup(_ filename: String) async throws {
        let backups = try await listBackups()
        
        for backup in backups {
            let fileURL = backup.appendingPathComponent(filename)
            if fileManager.fileExists(at: fileURL) {
                try await fileManager.deleteFile(at: fileURL)
            }
        }
    }
    
    func listBackups() async throws -> [URL] {
        let contents = try await fileManager.listFiles(in: backupDirectory)
        return contents.sorted { url1, url2 in
            let date1 = try? fileManager.getFileModificationDate(at: url1)
            let date2 = try? fileManager.getFileModificationDate(at: url2)
            return date1 ?? Date.distantPast > date2 ?? Date.distantPast
        }
    }
    
    // MARK: - Private Methods
    private func setupBackupSchedule() {
        // Schedule daily backup check
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkBackupSchedule()
        }
    }
    
    private func checkBackupSchedule() {
        guard shouldPerformBackup() else { return }
        
        // Trigger backup of all important files
        Task {
            do {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let files = try await fileManager.listFiles(in: documents)
                
                for file in files where file.pathExtension == "json" {
                    try await backup(file)
                }
            } catch {
                print("Scheduled backup failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func shouldPerformBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        return Date().timeIntervalSince(lastBackup) >= backupInterval
    }
    
    private func pruneOldBackups() async throws {
        var backups = try await listBackups()
        
        // Keep only the most recent backups
        if backups.count > maxBackupCount {
            backups = Array(backups.prefix(maxBackupCount))
            
            // Delete older backups
            let oldBackups = backups.suffix(from: maxBackupCount)
            for backup in oldBackups {
                try await fileManager.deleteFile(at: backup)
            }
        }
    }
}

// MARK: - Error Types
enum BackupError: Error {
    case initializationFailed
    case backupFailed
    case restorationFailed
    case noBackupsAvailable
    
    var localizedDescription: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize backup manager"
        case .backupFailed:
            return "Failed to create backup"
        case .restorationFailed:
            return "Failed to restore from backup"
        case .noBackupsAvailable:
            return "No backups available for restoration"
        }
    }
}
