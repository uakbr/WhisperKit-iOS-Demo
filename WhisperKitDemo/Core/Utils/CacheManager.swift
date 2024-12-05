//
// CacheManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation

/// Manages caching of transcription results and audio data
actor CacheManager {
    private let fileManager: FileManaging
    private let logger: Logging
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024  // 500MB
    
    private var cachedItems: [CacheItem] = []
    private var currentCacheSize: Int64 = 0
    
    init(fileManager: FileManaging, logger: Logging) throws {
        self.fileManager = fileManager
        self.logger = logger.scoped(for: "CacheManager")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsPath.appendingPathComponent("Cache")
        
        try createCacheDirectoryIfNeeded()
        try loadCacheMetadata()
    }
    
    /// Stores data in cache
    func store(_ data: Data, for key: String) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let fileSize = Int64(data.count)
        
        // Check if cache cleanup is needed
        if currentCacheSize + fileSize > maxCacheSize {
            try await cleanupCache(neededSpace: fileSize)
        }
        
        // Write data to cache
        try data.write(to: fileURL)
        
        // Update metadata
        let item = CacheItem(key: key,
                            size: fileSize,
                            timestamp: Date())
        cachedItems.append(item)
        currentCacheSize += fileSize
        
        try saveCacheMetadata()
        logger.debug("Cached item: \(key) (\(formatBytes(fileSize)))")
    }
    
    /// Retrieves data from cache
    func retrieve(_ key: String) async throws -> Data {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CacheError.itemNotFound
        }
        
        // Update access timestamp
        if let index = cachedItems.firstIndex(where: { $0.key == key }) {
            cachedItems[index].lastAccessed = Date()
            try saveCacheMetadata()
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    /// Removes item from cache
    func remove(_ key: String) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let item = cachedItems.first(where: { $0.key == key }) else {
            throw CacheError.itemNotFound
        }
        
        try FileManager.default.removeItem(at: fileURL)
        cachedItems.removeAll { $0.key == key }
        currentCacheSize -= item.size
        
        try saveCacheMetadata()
        logger.debug("Removed cached item: \(key)")
    }
    
    /// Clears all cached items
    func clearCache() async throws {
        let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                 includingPropertiesForKeys: nil)
        for url in contents {
            try FileManager.default.removeItem(at: url)
        }
        
        cachedItems.removeAll()
        currentCacheSize = 0
        try saveCacheMetadata()
        
        logger.info("Cache cleared")
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() throws {
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.createDirectory(at: cacheDirectory,
                                                  withIntermediateDirectories: true)
        }
    }
    
    private func loadCacheMetadata() throws {
        let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return
        }
        
        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(CacheMetadata.self, from: data)
        
        self.cachedItems = metadata.items
        self.currentCacheSize = metadata.items.reduce(0) { $0 + $1.size }
        
        logger.debug("Loaded cache metadata: \(cachedItems.count) items, \(formatBytes(currentCacheSize))")
    }
    
    private func saveCacheMetadata() throws {
        let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
        let metadata = CacheMetadata(items: cachedItems)
        
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
    }
    
    private func cleanupCache(neededSpace: Int64) async throws {
        // Sort items by last accessed time
        let sortedItems = cachedItems.sorted { $0.lastAccessed < $1.lastAccessed }
        
        var freedSpace: Int64 = 0
        for item in sortedItems {
            // Stop if we've freed enough space
            if currentCacheSize - freedSpace + neededSpace <= maxCacheSize {
                break
            }
            
            try await remove(item.key)
            freedSpace += item.size
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

struct CacheItem: Codable {
    let key: String
    let size: Int64
    let timestamp: Date
    var lastAccessed: Date
    
    init(key: String, size: Int64, timestamp: Date) {
        self.key = key
        self.size = size
        self.timestamp = timestamp
        self.lastAccessed = timestamp
    }
}

struct CacheMetadata: Codable {
    let items: [CacheItem]
}

enum CacheError: Error {
    case itemNotFound
}
