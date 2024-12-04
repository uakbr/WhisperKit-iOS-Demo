import Foundation
import CloudKit
import Combine

/// Manages synchronization with iCloud
class iCloudSyncManager {
    // MARK: - Properties
    private let container: CKContainer
    private let database: CKDatabase
    private let fileManager = FileOperationsManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Initialization
    init(containerIdentifier: String? = nil) {
        container = containerIdentifier.map { CKContainer(identifier: $0) } ?? .default()
        database = container.privateCloudDatabase
        
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func sync(_ fileURL: URL) async throws {
        guard iCloudIsAvailable() else {
            throw iCloudError.unavailable
        }
        
        await setIsSyncing(true)
        defer { Task { await setIsSyncing(false) } }
        
        do {
            // Create record
            let record = try await createRecord(for: fileURL)
            
            // Upload to iCloud
            try await database.save(record)
            
            await MainActor.run {
                lastSyncDate = Date()
            }
        } catch {
            throw iCloudError.syncFailed(error)
        }
    }
    
    func delete(_ fileURL: URL) async throws {
        guard iCloudIsAvailable() else {
            throw iCloudError.unavailable
        }
        
        let recordID = try recordID(for: fileURL)
        
        do {
            try await database.deleteRecord(withID: recordID)
        } catch {
            throw iCloudError.deleteFailed(error)
        }
    }
    
    func fetchChanges() async throws {
        guard iCloudIsAvailable() else {
            throw iCloudError.unavailable
        }
        
        await setIsSyncing(true)
        defer { Task { await setIsSyncing(false) } }
        
        do {
            let changes = try await fetchDatabaseChanges()
            try await processFetchedChanges(changes)
            
            await MainActor.run {
                lastSyncDate = Date()
            }
        } catch {
            throw iCloudError.fetchFailed(error)
        }
    }
    
    // MARK: - Private Methods
    @MainActor
    private func setIsSyncing(_ value: Bool) {
        isSyncing = value
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                Task {
                    try? await self?.fetchChanges()
                }
            }
            .store(in: &cancellables)
        
        // Monitor iCloud account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                self?.handleAccountChanged()
            }
            .store(in: &cancellables)
    }
    
    private func iCloudIsAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func createRecord(for fileURL: URL) async throws -> CKRecord {
        let recordID = try recordID(for: fileURL)
        let record = CKRecord(recordType: "TranscriptionFile", recordID: recordID)
        
        // Add file data
        let asset = try CKAsset(fileURL: fileURL)
        record["fileData"] = asset
        record["fileName"] = fileURL.lastPathComponent
        record["modificationDate"] = Date()
        
        return record
    }
    
    private func recordID(for fileURL: URL) throws -> CKRecord.ID {
        let filename = fileURL.lastPathComponent
        return CKRecord.ID(recordName: "file-\(filename)")
    }
    
    private func fetchDatabaseChanges() async throws -> [CKRecord] {
        var changes: [CKRecord] = []
        
        let query = CKQuery(recordType: "TranscriptionFile", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let results = try await database.records(matching: query)
        changes = results.matchResults.compactMap { try? $0.1.get() }
        
        return changes
    }
    
    private func processFetchedChanges(_ changes: [CKRecord]) async throws {
        for record in changes {
            guard let asset = record["fileData"] as? CKAsset,
                  let filename = record["fileName"] as? String,
                  let fileURL = asset.fileURL else {
                continue
            }
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsURL.appendingPathComponent(filename)
            
            try await fileManager.copyFile(from: fileURL, to: destinationURL)
        }
    }
    
    private func handleAccountChanged() {
        Task {
            if iCloudIsAvailable() {
                try? await fetchChanges()
            }
        }
    }
}

// MARK: - Error Types
enum iCloudError: Error {
    case unavailable
    case syncFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .unavailable:
            return "iCloud is not available"
        case .syncFailed(let error):
            return "Failed to sync with iCloud: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch changes from iCloud: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from iCloud: \(error.localizedDescription)"
        }
    }
}
