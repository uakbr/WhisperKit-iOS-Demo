import Foundation

/// Implements caching for quick access to recent data
class CacheManager {
    // MARK: - Properties
    private let cache = NSCache<NSString, AnyObject>()
    private let fileManager = FileOperationsManager()
    private let queue = DispatchQueue(label: "com.whisperkit.cache", qos: .utility)
    
    private let maxMemoryLimit: Int = 50 * 1024 * 1024  // 50 MB
    private let maxDiskLimit: Int = 200 * 1024 * 1024    // 200 MB
    
    private let cacheDirectory: URL
    
    // MARK: - Initialization
    init() {
        // Configure cache limits
        cache.totalCostLimit = maxMemoryLimit
        
        // Set up cache directory
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = baseURL.appendingPathComponent("WhisperKitCache")
        
        try? fileManager.createDirectory(at: cacheDirectory)
        
        // Start maintenance timer
        startMaintenanceTimer()
    }
    
    // MARK: - Public Methods
    func cache<T: Codable>(_ object: T, forKey key: String, cost: Int = 1) {
        // Cache in memory
        if let data = try? JSONEncoder().encode(object) {
            cache.setObject(data as AnyObject, forKey: key as NSString, cost: cost)
            
            // Cache to disk asynchronously
            cacheToDisk(data, forKey: key)
        }
    }
    
    func get<T: Codable>(forKey key: String) -> T? {
        // Try memory cache first
        if let cached = cache.object(forKey: key as NSString) as? Data {
            return try? JSONDecoder().decode(T.self, from: cached)
        }
        
        // Try disk cache
        return getFromDisk(forKey: key)
    }
    
    func remove(forKey key: String) {
        // Remove from memory
        cache.removeObject(forKey: key as NSString)
        
        // Remove from disk
        removeFromDisk(forKey: key)
    }
    
    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear disk cache
        clearDiskCache()
    }
    
    // MARK: - Private Methods
    private func cacheToDisk(_ data: Data, forKey key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.cacheDirectory.appendingPathComponent(key)
            try? data.write(to: fileURL)
            
            // Check disk cache size and trim if needed
            self.trimDiskCacheIfNeeded()
        }
    }
    
    private func getFromDisk<T: Codable>(forKey key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        // Update access time
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        
        // Cache in memory for future use
        cache.setObject(data as AnyObject, forKey: key as NSString)
        
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func removeFromDisk(forKey key: String) {
        queue.async { [weak self] in
            let fileURL = self?.cacheDirectory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: fileURL!)
        }
    }
    
    private func clearDiskCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            try? FileManager.default.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory)
        }
    }
    
    private func trimDiskCacheIfNeeded() {
        guard let contents = try? fileManager.listFiles(in: cacheDirectory) else { return }
        
        // Calculate total size
        var totalSize: UInt64 = 0
        var files: [(url: URL, size: UInt64, date: Date)] = []
        
        for fileURL in contents {
            guard let size = try? fileManager.getFileSize(at: fileURL),
                  let date = try? fileManager.getFileModificationDate(at: fileURL) else {
                continue
            }
            
            totalSize += size
            files.append((fileURL, size, date))
        }
        
        // If we're over the limit, remove oldest files first
        if totalSize > maxDiskLimit {
            let sorted = files.sorted { $0.date < $1.date }
            
            for file in sorted {
                try? FileManager.default.removeItem(at: file.url)
                totalSize -= file.size
                
                if totalSize <= maxDiskLimit {
                    break
                }
            }
        }
    }
    
    private func startMaintenanceTimer() {
        // Run maintenance every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performMaintenance()
        }
    }
    
    private func performMaintenance() {
        queue.async { [weak self] in
            self?.trimDiskCacheIfNeeded()
        }
    }
}
