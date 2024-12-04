import Foundation
import WhisperKit
import CoreML

/// Optimizes model performance and memory usage for WhisperKit models
class ModelPerformanceOptimizer {
    // MARK: - Properties
    private let deviceCapabilities: DeviceCapabilities
    
    // MARK: - Initialization
    init() {
        self.deviceCapabilities = DeviceCapabilities()
    }
    
    // MARK: - Public Methods
    func optimize(_ model: WhisperModel) async throws -> WhisperModel {
        // Create configuration based on device capabilities
        let config = try createOptimalConfiguration()
        
        // Apply optimizations
        return try await optimizeModel(model, with: config)
    }
    
    // MARK: - Private Methods
    private func createOptimalConfiguration() throws -> MLModelConfiguration {
        let config = MLModelConfiguration()
        
        // Configure compute units based on device capabilities
        if deviceCapabilities.hasNeuralEngine {
            config.computeUnits = .all
        } else if deviceCapabilities.hasGPU {
            config.computeUnits = .cpuAndGPU
        } else {
            config.computeUnits = .cpuOnly
        }
        
        // Set memory options
        config.allowLowPrecisionAccumulationOnGPU = true
        config.preferredMetalDevice = MTLCreateSystemDefaultDevice()
        
        return config
    }
    
    private func optimizeModel(_ model: WhisperModel, with config: MLModelConfiguration) async throws -> WhisperModel {
        // Apply model-specific optimizations
        try await model.optimize(config: config)
        
        // Configure batch processing
        let batchSize = determineBatchSize()
        try await model.setBatchSize(batchSize)
        
        // Set up memory management
        try configureMemoryManagement(for: model)
        
        return model
    }
    
    private func determineBatchSize() -> Int {
        // Calculate optimal batch size based on available memory and device capabilities
        let memoryLimit = deviceCapabilities.availableMemory
        let processingPower = deviceCapabilities.computePerformanceScore
        
        // Scale batch size based on device capabilities
        let baseBatchSize = 16
        let scaleFactor = min(1.0, Double(memoryLimit) / (2 * 1024 * 1024 * 1024)) // 2GB reference
        let adjustedBatchSize = Int(Double(baseBatchSize) * scaleFactor)
        
        return max(1, min(adjustedBatchSize, 32)) // Clamp between 1 and 32
    }
    
    private func configureMemoryManagement(for model: WhisperModel) throws {
        // Set up memory pools and caches
        if deviceCapabilities.hasGPU {
            try model.enableGPUMemoryPool()
        }
        
        // Configure cache size based on available memory
        let cacheSize = calculateOptimalCacheSize()
        try model.setCacheSize(cacheSize)
    }
    
    private func calculateOptimalCacheSize() -> Int {
        // Calculate cache size based on available memory
        let availableMemory = deviceCapabilities.availableMemory
        let memoryThreshold = 4 * 1024 * 1024 * 1024 // 4GB
        
        if availableMemory > memoryThreshold {
            return 1024 // Large cache for high-memory devices
        } else {
            return 512 // Smaller cache for limited memory
        }
    }
}

// MARK: - Device Capabilities Helper
class DeviceCapabilities {
    var hasNeuralEngine: Bool {
        if #available(iOS 15.0, *) {
            return true // Check actual Neural Engine availability
        }
        return false
    }
    
    var hasGPU: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    var availableMemory: Int {
        var pagesize: vm_size_t = 0
        var memsize: vm_size_t = 0
        
        host_page_size(mach_host_self(), &pagesize)
        host_statistics(mach_host_self(), HOST_VM_INFO, nil, &memsize)
        
        return Int(memsize) * Int(pagesize)
    }
    
    var computePerformanceScore: Float {
        // Calculate a performance score based on device capabilities
        var score: Float = 1.0
        
        if hasNeuralEngine { score *= 2.0 }
        if hasGPU { score *= 1.5 }
        
        return score
    }
}

// MARK: - Optimization Error Types
enum OptimizationError: Error {
    case configurationFailed
    case optimizationFailed(Error)
    case unsupportedDevice
    
    var localizedDescription: String {
        switch self {
        case .configurationFailed:
            return "Failed to create model configuration"
        case .optimizationFailed(let error):
            return "Model optimization failed: \(error.localizedDescription)"
        case .unsupportedDevice:
            return "Device does not meet minimum requirements for model optimization"
        }
    }
}
