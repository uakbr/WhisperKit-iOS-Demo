import Foundation
import WhisperKit
import Combine

/// Manages the lifecycle of WhisperKit transcription models
class ModelLifecycleManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var currentModel: WhisperModel?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingProgress: Float = 0.0
    @Published private(set) var availableModels: [WhisperModelInfo] = []
    
    private let modelOptimizer: ModelPerformanceOptimizer
    private let memoryManager: MemoryManager
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let defaultModelURL: URL
    private let modelStorageURL: URL
    
    // MARK: - Initialization
    init() {
        // Initialize supporting components
        modelOptimizer = ModelPerformanceOptimizer()
        memoryManager = MemoryManager()
        
        // Set up model storage paths
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        modelStorageURL = documentsPath.appendingPathComponent("WhisperModels")
        defaultModelURL = Bundle.main.url(forResource: "whisper-base", withExtension: "mlmodelc")!
        
        setupModelDirectory()
        loadAvailableModels()
    }
    
    // MARK: - Public Methods
    func loadModel(_ modelInfo: WhisperModelInfo) async throws {
        guard !isLoading else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Ensure sufficient memory
            try await memoryManager.ensureMemoryAvailable(for: modelInfo)
            
            // Release current model if needed
            await releaseCurrentModel()
            
            // Load and optimize new model
            let model = try await loadModelFromDisk(modelInfo)
            let optimizedModel = try await modelOptimizer.optimize(model)
            
            await MainActor.run {
                self.currentModel = optimizedModel
                self.isLoading = false
                self.loadingProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.loadingProgress = 0.0
            }
            throw ModelError.loadingFailed(error)
        }
    }
    
    func downloadModel(_ modelInfo: WhisperModelInfo) async throws {
        guard !isLoading else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Check storage space
            try await memoryManager.ensureStorageAvailable(for: modelInfo)
            
            // Download model
            let modelURL = try await downloadModelFromServer(modelInfo)
            
            // Move to permanent storage
            let destinationURL = modelStorageURL.appendingPathComponent(modelInfo.filename)
            try FileManager.default.moveItem(at: modelURL, to: destinationURL)
            
            // Update available models
            await loadAvailableModels()
            
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
            throw ModelError.downloadFailed(error)
        }
    }
    
    func deleteModel(_ modelInfo: WhisperModelInfo) throws {
        let modelURL = modelStorageURL.appendingPathComponent(modelInfo.filename)
        
        if currentModel?.modelInfo == modelInfo {
            Task {
                await releaseCurrentModel()
            }
        }
        
        try FileManager.default.removeItem(at: modelURL)
        loadAvailableModels()
    }
    
    // MARK: - Private Methods
    private func setupModelDirectory() {
        try? FileManager.default.createDirectory(
            at: modelStorageURL,
            withIntermediateDirectories: true
        )
    }
    
    private func loadAvailableModels() {
        do {
            let modelFiles = try FileManager.default.contentsOfDirectory(
                at: modelStorageURL,
                includingPropertiesForKeys: nil
            )
            
            availableModels = modelFiles.compactMap { url in
                guard url.pathExtension == "mlmodelc" else { return nil }
                return WhisperModelInfo(url: url)
            }
        } catch {
            print("Failed to load available models: \(error)")
        }
    }
    
    private func loadModelFromDisk(_ modelInfo: WhisperModelInfo) async throws -> WhisperModel {
        let modelURL = modelStorageURL.appendingPathComponent(modelInfo.filename)
        
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw ModelError.modelNotFound
        }
        
        return try await WithCancellationHandler {
            try WhisperModel.load(from: modelURL) { progress in
                Task { @MainActor in
                    self.loadingProgress = Float(progress)
                }
            }
        }
    }
    
    private func downloadModelFromServer(_ modelInfo: WhisperModelInfo) async throws -> URL {
        // Implementation depends on your server setup
        // This is a placeholder that should be replaced with actual download logic
        throw ModelError.downloadFailed(nil)
    }
    
    private func releaseCurrentModel() async {
        if let model = currentModel {
            await model.unload()
            await MainActor.run { currentModel = nil }
        }
    }
}

// MARK: - Supporting Types
struct WhisperModelInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let version: String
    let size: Int64
    let filename: String
    let languageSupport: Set<String>
    
    init(url: URL) {
        // Parse model info from URL or metadata
        // This is a placeholder implementation
        self.id = url.lastPathComponent
        self.name = url.deletingPathExtension().lastPathComponent
        self.version = "1.0"
        self.size = 0
        self.filename = url.lastPathComponent
        self.languageSupport = ["en"]
    }
}

enum ModelError: Error {
    case modelNotFound
    case loadingFailed(Error)
    case downloadFailed(Error?)
    case invalidModel
    
    var localizedDescription: String {
        switch self {
        case .modelNotFound:
            return "Model file not found"
        case .loadingFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download model: \(error?.localizedDescription ?? "Unknown error")"
        case .invalidModel:
            return "Invalid model file or format"
        }
    }
}
