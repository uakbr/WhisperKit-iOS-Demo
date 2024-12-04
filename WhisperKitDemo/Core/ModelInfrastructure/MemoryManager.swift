import Foundation
import Combine

/// Handles memory allocation and monitoring for large audio data and models
class MemoryManager {
    // MARK: - Properties
    private let memoryPressurePublisher = NotificationCenter.default
        .publisher(for: .NSMemoryPressureNotification)
    
    private let lowMemoryThreshold: UInt64 = 100 * 1024 * 1024  // 100MB
    private let criticalMemoryThreshold: UInt64 = 50 * 1024 * 1024  // 50MB
    
    private var cancellables = Set<AnyCancellable>()
    
    // Memory pressure handler
    var onMemoryPressure: ((MemoryPressureLevel) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupMemoryPressureMonitoring()
    }
    
    // MARK: - Public Methods
    func ensureMemoryAvailable(for modelInfo: WhisperModelInfo) async throws {
        let requiredMemory = modelInfo.size * 2  // Conservative estimate
        let availableMemory = getAvailableMemory()
        
        guard availableMemory > requiredMemory else {
            throw MemoryError.insufficientMemory(required: requiredMemory, available: availableMemory)
        }
        
        // Attempt to free up memory if needed
        if availableMemory - requiredMemory < lowMemoryThreshold {
            try await performMemoryCleanup()
        }
    }
    
    func ensureStorageAvailable(for modelInfo: WhisperModelInfo) async throws {
        let requiredSpace = modelInfo.size
        let availableSpace = getAvailableStorage()
        
        guard availableSpace > requiredSpace else {
            throw MemoryError.insufficientStorage(required: requiredSpace, available: availableSpace)
        }
    }
    
    func monitorMemoryUsage() -> AnyPublisher<MemoryMetrics, Never> {
        // Create a timer publisher for periodic memory updates
        return Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { [weak self] _ -> MemoryMetrics in
                guard let self = self else { return MemoryMetrics() }
                return self.getCurrentMemoryMetrics()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func setupMemoryPressureMonitoring() {
        memoryPressurePublisher
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                let level = self.memoryPressureLevel(from: notification)
                self.handleMemoryPressure(level)
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) {
        switch level {
        case .warning:
            Task {
                try? await performMemoryCleanup()
            }
        case .critical:
            Task {
                try? await performUrgentMemoryCleanup()
            }
        }
        
        onMemoryPressure?(level)
    }
    
    private func performMemoryCleanup() async throws {
        // Release cached resources
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary files
        try clearTemporaryFiles()
        
        // Suggest garbage collection
        suggestGarbageCollection()
    }
    
    private func performUrgentMemoryCleanup() async throws {
        // Perform aggressive cleanup
        try await performMemoryCleanup()
        
        // Release non-essential resources
        NotificationCenter.default.post(name: .urgentMemoryCleanupRequired, object: nil)
    }
    
    private func getAvailableMemory() -> UInt64 {
        var pagesize: vm_size_t = 0
        let host_port: mach_port_t = mach_host_self()
        host_page_size(host_port, &pagesize)
        
        var vm_stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        _ = withUnsafeMutablePointer(to: &vm_stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(host_port,
                                 HOST_VM_INFO64,
                                 ptr,
                                 &count)
            }
        }
        
        let free_memory = UInt64(vm_stats.free_count) * UInt64(pagesize)
        return free_memory
    }
    
    private func getAvailableStorage() -> UInt64 {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first else { return 0 }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            return attributes[.systemFreeSize] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func clearTemporaryFiles() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func suggestGarbageCollection() {
        #if DEBUG
        print("Memory warning: Suggesting garbage collection")
        #endif
        
        // Suggest garbage collection to the runtime
        autoreleasepool { }
    }
    
    private func memoryPressureLevel(from notification: Notification) -> MemoryPressureLevel {
        guard let level = notification.userInfo?["level"] as? Int else {
            return .warning
        }
        
        return level >= 2 ? .critical : .warning
    }
    
    private func getCurrentMemoryMetrics() -> MemoryMetrics {
        return MemoryMetrics(
            availableMemory: getAvailableMemory(),
            availableStorage: getAvailableStorage()
        )
    }
}

// MARK: - Supporting Types
struct MemoryMetrics {
    var availableMemory: UInt64 = 0
    var availableStorage: UInt64 = 0
}

enum MemoryPressureLevel {
    case warning
    case critical
}

enum MemoryError: Error {
    case insufficientMemory(required: UInt64, available: UInt64)
    case insufficientStorage(required: UInt64, available: UInt64)
    
    var localizedDescription: String {
        switch self {
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: Required \(bytesToMB(required))MB, Available \(bytesToMB(available))MB"
        case .insufficientStorage(let required, let available):
            return "Insufficient storage: Required \(bytesToMB(required))MB, Available \(bytesToMB(available))MB"
        }
    }
    
    private func bytesToMB(_ bytes: UInt64) -> Int {
        return Int(bytes / (1024 * 1024))
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let urgentMemoryCleanupRequired = Notification.Name("com.whisperkit.urgentMemoryCleanupRequired")
}
