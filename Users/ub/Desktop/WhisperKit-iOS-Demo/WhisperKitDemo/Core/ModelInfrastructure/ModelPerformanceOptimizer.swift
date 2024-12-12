import Foundation
import WhisperKit
import CoreML

/// Optimizes model performance and memory usage for WhisperKit models
class ModelPerformanceOptimizer {
    // MARK: - Properties
    private let deviceCapabilities: DeviceCapabilities
    private let logger: Logging
    private let defaultConfig: WhisperKitConfig
    
    // MARK: - Initialization
    init(logger: Logging) {
        self.deviceCapabilities = DeviceCapabilities()
        self.logger = logger.scoped(for: "ModelPerformanceOptimizer")
        
        // Create default configuration
        self.defaultConfig = WhisperKitConfig(
            computeUnits: deviceCapabilities.hasNeuralEngine ? .cpuAndNeuralEngine : .cpuOnly,
            memoryBudget: determineMemoryBudget()
        )
    }
    
    // MARK: - Public Methods
    func optimize(_ model: WhisperModel) async throws -> WhisperModel {
        logger.debug("Starting model optimization")
        
        // Apply optimizations based on device capabilities
        let config = createOptimalConfiguration(for: model)
        
        do {
            let optimizedModel = try await model.optimized(with: config)
            logger.info("Model optimization completed successfully")
            return optimizedModel
        } catch {
            logger.error("Model optimization failed: \(error.localizedDescription)")
            throw OptimizationError.optimizationFailed(error)
        }
    }
    
    // MARK: - Private Methods
    private func createOptimalConfiguration(for model: WhisperModel) -> WhisperKitConfig {
        var config = defaultConfig
        
        // Adjust batch size based on model size and available memory
        config.batchSize = determineBatchSize(for: model)
        
        // Configure memory management
        config.memoryBudget = determineMemoryBudget()
        
        // Set compute units based on device capabilities
        config.computeUnits = determineComputeUnits()
        
        return config
    }
    
    private func determineBatchSize(for model: WhisperModel) -> Int {
        let availableMemory = deviceCapabilities.availableMemory
        let modelSize = model.type.memoryRequirement
        
        // Calculate optimal batch size based on available memory
        let memoryPerBatch = modelSize / Int64(1024 * 1024) // Convert to MB
        let maxBatchSize = Int(availableMemory / memoryPerBatch)
        
        // Clamp between 1 and 32
        return min(max(1, maxBatchSize), 32)
    }
    
    private func determineMemoryBudget() -> Int {
        let totalMemory = deviceCapabilities.availableMemory
        
        // Use up to 70% of available memory
        return Int(Double(totalMemory) * 0.7)
    }
    
    private func determineComputeUnits() -> WhisperKitComputeUnits {
        if deviceCapabilities.hasNeuralEngine {
            return .cpuAndNeuralEngine
        } else if deviceCapabilities.hasGPU {
            return .cpuAndGPU
        } else {
            return .cpuOnly
        }
    }
}

// Keep existing supporting types...