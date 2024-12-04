//
// ModelManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine
import WhisperKit

/// Protocol defining model management capabilities
protocol ModelManaging {
    func downloadModel(_ model: WhisperKitModel) async throws
    func deleteModel(_ model: WhisperKitModel) throws
    func listDownloadedModels() throws -> [WhisperKitModel]
    func getModelPath(for model: WhisperKitModel) -> URL?
    func getDownloadProgress(for model: WhisperKitModel) -> AnyPublisher<Double, Never>
    var selectedModel: WhisperKitModel { get set }
}

/// Manager class responsible for handling WhisperKit model operations
public final class ModelManager: ModelManaging {
    
    // MARK: - Properties
    
    private let fileManager: FileManaging
    private let errorManager: ErrorHandling
    private let logger: Logging
    
    private let modelBaseURL = "https://huggingface.co/whisperkit/models/resolve/main"
    private var downloadProgressSubjects: [WhisperKitModel: CurrentValueSubject<Double, Never>] = [:]
    
    @Published public private(set) var selectedModel: WhisperKitModel = .tiny
    
    // MARK: - Initialization
    
    init(fileManager: FileManaging, errorManager: ErrorHandling, logger: Logging) {
        self.fileManager = fileManager
        self.errorManager = errorManager
        self.logger = logger.scoped(for: "ModelManager")
    }
    
    // MARK: - Public Methods
    
    /// Downloads a WhisperKit model
    /// - Parameter model: The model to download
    public func downloadModel(_ model: WhisperKitModel) async throws {
        logger.info("Starting download for model: \(model.rawValue)")
        
        let progressSubject = CurrentValueSubject<Double, Never>(0.0)
        downloadProgressSubjects[model] = progressSubject
        
        defer {
            downloadProgressSubjects.removeValue(forKey: model)
        }
        
        let modelURL = URL(string: "\(modelBaseURL)/\(model.rawValue).mlmodelc.zip")!
        let downloadTask = URLSession.shared.downloadTask(with: modelURL) { [weak self] url, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorManager.handle(.modelError("Failed to download model: \(error.localizedDescription)"))
                return
            }
            
            guard let url = url else {
                self.errorManager.handle(.modelError("Download completed but file URL is missing"))
                return
            }
            
            do {
                let modelData = try Data(contentsOf: url)
                try self.unzipAndSaveModel(modelData, for: model)
                self.logger.info("Successfully downloaded and saved model: \(model.rawValue)")
            } catch {
                self.errorManager.handle(.modelError("Failed to process downloaded model: \(error.localizedDescription)"))
            }
        }
        
        // Observe download progress
        let observation = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            self?.downloadProgressSubjects[model]?.send(progress.fractionCompleted)
        }
        
        downloadTask.resume()
        
        // Wait for download completion
        for await _ in downloadTask.progress.publisher(for: \.fractionCompleted).values {
            if downloadTask.progress.fractionCompleted >= 1.0 {
                break
            }
        }
        
        observation.invalidate()
    }
    
    /// Deletes a WhisperKit model
    /// - Parameter model: The model to delete
    public func deleteModel(_ model: WhisperKitModel) throws {
        logger.info("Deleting model: \(model.rawValue)")
        
        guard let modelPath = getModelPath(for: model) else {
            throw WhisperKitError.modelError("Model not found: \(model.rawValue)")
        }
        
        try fileManager.deleteModel(modelPath.lastPathComponent)
        
        if selectedModel == model {
            selectedModel = .tiny // Reset to default model
        }
        
        logger.info("Successfully deleted model: \(model.rawValue)")
    }
    
    /// Lists all downloaded WhisperKit models
    /// - Returns: Array of downloaded models
    public func listDownloadedModels() throws -> [WhisperKitModel] {
        let modelNames = try fileManager.listModels()
        
        return modelNames.compactMap { modelName -> WhisperKitModel? in
            let cleanName = modelName.replacingOccurrences(of: ".mlmodelc", with: "")
            return WhisperKitModel(rawValue: cleanName)
        }
    }
    
    /// Gets the file path for a specific model
    /// - Parameter model: The model to get the path for
    /// - Returns: URL of the model if it exists
    public func getModelPath(for model: WhisperKitModel) -> URL? {
        let modelName = "\(model.rawValue).mlmodelc"
        let models = (try? fileManager.listModels()) ?? []
        
        guard models.contains(modelName) else {
            return nil
        }
        
        return try? fileManager.applicationDirectory()
            .appendingPathComponent("Models")
            .appendingPathComponent(modelName)
    }
    
    /// Gets the download progress publisher for a specific model
    /// - Parameter model: The model to get progress for
    /// - Returns: Publisher emitting download progress values
    public func getDownloadProgress(for model: WhisperKitModel) -> AnyPublisher<Double, Never> {
        return downloadProgressSubjects[model]?.eraseToAnyPublisher() 
            ?? Just(0.0).eraseToAnyPublisher()
    }
    
    /// Updates the selected model
    /// - Parameter model: The model to select
    public func selectModel(_ model: WhisperKitModel) throws {
        guard let _ = getModelPath(for: model) else {
            throw WhisperKitError.modelError("Cannot select model that is not downloaded: \(model.rawValue)")
        }
        
        selectedModel = model
        logger.info("Selected model changed to: \(model.rawValue)")
    }
    
    // MARK: - Private Methods
    
    private func unzipAndSaveModel(_ modelData: Data, for model: WhisperKitModel) throws {
        // Create temporary directory for unzipping
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Write zip file
        let zipPath = tempDir.appendingPathComponent("model.zip")
        try modelData.write(to: zipPath)
        
        // Unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipPath.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw WhisperKitError.modelError("Failed to unzip model file")
        }
        
        // Save unzipped model
        let modelName = "\(model.rawValue).mlmodelc"
        let unzippedModelPath = tempDir.appendingPathComponent(modelName)
        let modelData = try Data(contentsOf: unzippedModelPath)
        try fileManager.saveModel(modelData, name: modelName)
        
        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }
}
