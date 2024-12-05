import Foundation
import WhisperKit
import CoreML

/// Optimizes model performance and memory usage for WhisperKit models
class ModelPerformanceOptimizer {
    // MARK: - Properties
    private let deviceCapabilities: DeviceCapabilities
    private let logger: Logging
    
    // MARK: - Initialization
    init(logger: Logging) {
        self.deviceCapabilities = DeviceCapabilities()
        self.logger = logger.scoped(for: "ModelPerformanceOptimizer")
    }
    
    // MARK: - Public Methods
    func optimize(_ model: WhisperModel) async throws -> WhisperModel {
        logger.debug("Starting model optimization")
        logger.debug("Available memory: \(formatBytes(deviceCapabilities.availableMemory))")
        logger.debug("Neural Engine: \(deviceCapabilities.hasNeuralEngine)")
        logger.debug("GPU: \(deviceCapabilities.hasGPU)")
        
        // Create configuration based on device capabilities
        let config = try createOptimalConfiguration()
        
        // Apply optimizations
        let optimizedModel = try await optimizeModel(model, with: config)
        logger.info("Model optimization completed successfully")
        
        return optimizedModel
    }
    
    // MARK: - Private Methods
    private func createOptimalConfiguration() throws -> MLModelConfiguration {
        let config = MLModelConfiguration()
        
        // Configure compute units based on device capabilities
        if deviceCapabilities.hasNeuralEngine {
            config.computeUnits = .all
            logger.debug("Using all compute units (CPU + Neural Engine + GPU)")
        } else if deviceCapabilities.hasGPU {
            config.computeUnits = .cpuAndGPU
            logger.debug("Using CPU and GPU")
        } else {
            config.computeUnits = .cpuOnly
            logger.debug("Using CPU only")
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
        logger.debug("Set batch size to: \(batchSize)")
        
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
            logger.debug("Enabled GPU memory pool")
        }
        
        // Configure cache size based on available memory
        let cacheSize = calculateOptimalCacheSize()
        try model.setCacheSize(cacheSize)
        logger.debug("Set cache size to: \(cacheSize)")
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
    
    private func formatBytes(_ bytes: Int) -> String {
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
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 2 * 1024 * 1024 * 1024 // Default to 2GB if unable to get memory stats
        }
        
        let pageSize = vm_kernel_page_size
        let freeMemory = Int(stats.free_count) * Int(pageSize)
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        return min(Int(freeMemory), Int(totalMemory))
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
