import Foundation
import CloudKit
import Combine

/// Manages synchronization with iCloud
class iCloudSyncManager {
    // MARK: - Properties
    private let container: CKContainer
    private let database: CKDatabase
    private let fileManager = FileOperationsManager()
    private let zoneID = CKRecordZone.ID(zoneName: "WhisperKitZone", ownerName: CKCurrentUserDefaultName)
    
    private var subscriptions = Set<AnyCancellable>()
    private var lastToken: CKServerChangeToken?
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Initialization
    init(containerIdentifier: String? = nil) {
        container = containerIdentifier.map { CKContainer(identifier: $0) } ?? .default()
        database = container.privateCloudDatabase
        
        setupZone()
        setupSubscriptions()
    }
    
    // MARK: - Private Methods
    private func setupZone() {
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .utility
        
        operation.modifyRecordZonesCompletionBlock = { _, _, error in
            if let error = error {
                print("Failed to create zone: \(error.localizedDescription)")
            }
        }
        
        database.add(operation)
    }
    
    private func setupSubscriptions() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.qualityOfService = .utility
        
        operation.modifySubscriptionsCompletionBlock = { _, _, error in
            if let error = error {
                print("Failed to create subscription: \(error.localizedDescription)")
            }
        }
        
        database.add(operation)
    }
    
    // Keep existing methods but update with proper zone handling...
}

// MARK: - Supporting Types
extension CKRecord {
    static let recordType = "WhisperKitTranscription"
    
    enum Keys {
        static let fileName = "fileName"
        static let fileData = "fileData"
        static let timestamp = "timestamp"
        static let modificationDate = "modificationDate"
    }
}

extension Notification.Name {
    static let iCloudSyncCompleted = Notification.Name("com.whisperkit.iCloudSyncCompleted")
    static let iCloudSyncFailed = Notification.Name("com.whisperkit.iCloudSyncFailed")
}