//
// TranscriptionManager.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import WhisperKit

/// Protocol defining transcription capabilities
protocol TranscriptionManaging {
    func transcribe(audioURL: URL) async throws -> TranscriptionResult
    func transcribeInRealTime(audioStream: AsyncStream<AVAudioPCMBuffer>) async throws -> AsyncStream<TranscriptionResult>
    func cancelTranscription()
    var isTranscribing: Bool { get }
    var progressPublisher: AnyPublisher<Double, Never> { get }
}

/// Structure representing the result of a transcription
public struct TranscriptionResult: Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let segments: [TranscriptionSegment]
    public let audioURL: URL?
    public let language: String?
    public let duration: TimeInterval
    public let timestamp: Date
    
    public init(id: UUID = UUID(),
                text: String,
                segments: [TranscriptionSegment],
                audioURL: URL? = nil,
                language: String? = nil,
                duration: TimeInterval,
                timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.segments = segments
        self.audioURL = audioURL
        self.language = language
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// Structure representing a segment of transcribed text
public struct TranscriptionSegment: Codable, Identifiable {
    public let id: Int
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let probability: Float
    
    public init(id: Int,
                text: String,
                start: TimeInterval,
                end: TimeInterval,
                probability: Float) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.probability = probability
    }
}

/// Manager class responsible for handling WhisperKit transcription operations
public final class TranscriptionManager: TranscriptionManaging {
    
    // MARK: - Properties
    
    private let modelManager: ModelManaging
    private let errorManager: ErrorHandling
    private let logger: Logging
    
    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<Void, Error>?
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    
    @Published private(set) var isTranscribing = false
    
    public var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(modelManager: ModelManaging,
         errorManager: ErrorHandling,
         logger: Logging) {
        self.modelManager = modelManager
        self.errorManager = errorManager
        self.logger = logger.scoped(for: "TranscriptionManager")
        
        setupWhisperKit()
    }
    
    // MARK: - Public Methods
    
    /// Transcribes an audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Returns: The transcription result
    public func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.transcriptionError("WhisperKit is not initialized")
        }
        
        isTranscribing = true
        progressSubject.send(0.0)
        
        defer {
            isTranscribing = false
            progressSubject.send(0.0)
        }
        
        logger.info("Starting transcription for audio file: \(audioURL.lastPathComponent)")
        
        let startTime = Date()
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            let config = TranscriptionConfig(language: nil, // Auto-detect
                                           task: .transcribe,
                                           progressHandler: { [weak self] progress in
                self?.progressSubject.send(progress)
            })
            
            let whisperResult = try await whisperKit.transcribe(audioData: audioData,
                                                               config: config)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.info("Transcription completed in \(String(format: "%.2f", duration)) seconds")
            
            return TranscriptionResult(
                text: whisperResult.text,
                segments: whisperResult.segments.enumerated().map { index, segment in
                    TranscriptionSegment(
                        id: index,
                        text: segment.text,
                        start: segment.start,
                        end: segment.end,
                        probability: segment.probability
                    )
                },
                audioURL: audioURL,
                language: whisperResult.language,
                duration: duration
            )
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            throw WhisperKitError.transcriptionError(error.localizedDescription)
        }
    }
    
    /// Transcribes audio in real-time from an audio stream
    /// - Parameter audioStream: Stream of audio buffers to transcribe
    /// - Returns: Stream of transcription results
    public func transcribeInRealTime(audioStream: AsyncStream<AVAudioPCMBuffer>) async throws -> AsyncStream<TranscriptionResult> {
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.transcriptionError("WhisperKit is not initialized")
        }
        
        return AsyncStream { continuation in
            transcriptionTask = Task {
                isTranscribing = true
                progressSubject.send(0.0)
                
                defer {
                    isTranscribing = false
                    progressSubject.send(0.0)
                    continuation.finish()
                }
                
                var buffer = Data()
                var startTime = Date()
                
                for await audioBuffer in audioStream {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    
                    // Append audio buffer data
                    buffer.append(contentsOf: audioBuffer.toData())
                    
                    // Process in chunks or after silence detection
                    if buffer.count >= WhisperKit.minimumAudioDuration || isSilence(audioBuffer) {
                        let config = TranscriptionConfig(
                            language: nil,
                            task: .transcribe,
                            progressHandler: { [weak self] progress in
                                self?.progressSubject.send(progress)
                            })
                        
                        let result = try await whisperKit.transcribe(audioData: buffer,
                                                                    config: config)
                        
                        let duration = Date().timeIntervalSince(startTime)
                        
                        let transcriptionResult = TranscriptionResult(
                            text: result.text,
                            segments: result.segments.enumerated().map { index, segment in
                                TranscriptionSegment(
                                    id: index,
                                    text: segment.text,
                                    start: segment.start,
                                    end: segment.end,
                                    probability: segment.probability
                                )
                            },
                            language: result.language,
                            duration: duration
                        )
                        
                        continuation.yield(transcriptionResult)
                        
                        // Reset for next chunk
                        buffer.removeAll()
                        startTime = Date()
                    }
                }
            }
            
            transcriptionTask?.result.map { _ in
                continuation.finish()
            }
        }
    }
    
    /// Cancels any ongoing transcription
    public func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
        progressSubject.send(0.0)
        logger.info("Transcription cancelled")
    }
    
    // MARK: - Private Methods
    
    private func setupWhisperKit() {
        do {
            let config = WhisperKitConfig(
                modelPath: modelManager.getModelPath(for: modelManager.selectedModel)?.path,
                computeUnits: .cpuAndNeuralEngine
            )
            whisperKit = try WhisperKit(config: config)
            logger.info("WhisperKit initialized successfully")
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")
            errorManager.handle(.modelError("Failed to initialize WhisperKit: \(error.localizedDescription)"))
        }
    }
    
    private func isSilence(_ buffer: AVAudioPCMBuffer, threshold: Float = 0.01) -> Bool {
        guard let channelData = buffer.floatChannelData else { return false }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                if abs(data[frame]) > threshold {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - Extensions

extension AVAudioPCMBuffer {
    func toData() -> Data {
        let channelCount = Int(format.channelCount)
        let frameLength = Int(frameLength)
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        
        var data = Data(count: frameLength * Int(bytesPerFrame))
        data.withUnsafeMutableBytes { ptr in
            for channel in 0..<channelCount {
                let channelData = floatChannelData?[channel]
                for frame in 0..<frameLength {
                    let offset = frame * channelCount + channel
                    let value = channelData?[frame] ?? 0
                    ptr.storeBytes(of: value, toByteOffset: offset * 4, as: Float.self)
                }
            }
        }
        
        return data
    }
}
