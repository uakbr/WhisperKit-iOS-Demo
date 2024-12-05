//
// ModelPerformanceOptimizer.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import WhisperKit

/// Optimizes WhisperKit model performance based on device capabilities and settings
class ModelPerformanceOptimizer {
    private let deviceProfile: DeviceProfile
    private let logger: Logging
    
    init(logger: Logging) {
        self.deviceProfile = DeviceProfile()
        self.logger = logger.scoped(for: "ModelPerformanceOptimizer")
    }
    
    /// Determines the optimal model type for the device
    func getOptimalModelType() -> WhisperModel.ModelType {
        let availableMemory = deviceProfile.availableMemory
        let processorCount = deviceProfile.processorCount
        
        // Log device capabilities
        logger.debug("Available memory: \(formatBytes(availableMemory))")
        logger.debug("Processor count: \(processorCount)")
        
        // Choose model based on available memory
        let modelType: WhisperModel.ModelType
        switch availableMemory {
        case _ where availableMemory >= 6 * 1024 * 1024 * 1024:  // 6GB
            modelType = .large
        case _ where availableMemory >= 3 * 1024 * 1024 * 1024:  // 3GB
            modelType = .medium
        case _ where availableMemory >= 1.5 * 1024 * 1024 * 1024:  // 1.5GB
            modelType = .small
        case _ where availableMemory >= 750 * 1024 * 1024:  // 750MB
            modelType = .base
        default:
            modelType = .tiny
        }
        
        logger.info("Selected optimal model type: \(modelType.rawValue)")
        return modelType
    }
    
    /// Gets recommended compute units based on device capabilities
    func getRecommendedComputeUnits() -> ComputeUnits {
        if deviceProfile.hasNeuralEngine {
            if deviceProfile.processorCount >= 4 {
                return .cpuAndNeuralEngine
            } else {
                return .neuralEngine
            }
        } else {
            return .cpu
        }
    }
    
    /// Determines if the device can handle real-time transcription
    func canHandleRealTimeTranscription(with model: WhisperModel) -> Bool {
        let requiredMemory = model.type.memoryRequirement * 2  // Double for safety margin
        let availableMemory = deviceProfile.availableMemory
        
        let hasEnoughMemory = availableMemory >= requiredMemory
        let hasEnoughCores = deviceProfile.processorCount >= 4
        
        logger.debug("Real-time transcription check:")
        logger.debug("Required memory: \(formatBytes(requiredMemory))")
        logger.debug("Available memory: \(formatBytes(availableMemory))")
        logger.debug("Has enough cores: \(hasEnoughCores)")
        
        return hasEnoughMemory && hasEnoughCores
    }
    
    // MARK: - Private Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gigabyte = Double(bytes) / 1_073_741_824
        if gigabyte >= 1 {
            return String(format: "%.1f GB", gigabyte)
        }
        
        let megabyte = Double(bytes) / 1_048_576
        if megabyte >= 1 {
            return String(format: "%.1f MB", megabyte)
        }
        
        let kilobyte = Double(bytes) / 1_024
        if kilobyte >= 1 {
            return String(format: "%.1f KB", kilobyte)
        }
        
        return "\(bytes) bytes"
    }
}

/// Profile of device capabilities
private struct DeviceProfile {
    let processorCount: Int
    let availableMemory: Int64
    let hasNeuralEngine: Bool
    
    init() {
        self.processorCount = ProcessInfo.processInfo.processorCount
        self.availableMemory = Self.getAvailableMemory()
        self.hasNeuralEngine = true  // We'll assume Neural Engine is available on modern devices
    }
    
    private static func getAvailableMemory() -> Int64 {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 2 * 1024 * 1024 * 1024  // Default to 2GB if unable to get memory stats
        }
        
        let pageSize = vm_kernel_page_size
        let freeMemory = Int64(stats.free_count) * Int64(pageSize)
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        return min(freeMemory, Int64(totalMemory))
    }
}
