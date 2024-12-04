//
// AudioProcessor.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate

/// General audio processing utilities
public class AudioProcessor {
    // MARK: - Properties
    
    private let bufferSize: AVAudioFrameCount = 4096
    private var fftSetup: vDSP_DFT_Setup?
    
    private let audioEngine: AVAudioEngine
    private let errorManager: ErrorHandling
    
    // Audio settings
    private let sampleRate: Double = 16000  // WhisperKit requirement
    private let channelCount: AVAudioChannelCount = 1
    
    // MARK: - Initialization
    
    init(audioEngine: AVAudioEngine, errorManager: ErrorHandling) {
        self.audioEngine = audioEngine
        self.errorManager = errorManager
        
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(bufferSize),
            vDSP_DFT_Direction.FORWARD
        )
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Public Methods
    
    /// Converts an audio buffer to a standardized format
    public func standardize(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let format = buffer.format.standardizedFormat else {
            throw AudioProcessingError.invalidBuffer
        }
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: buffer.frameLength
        ) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        do {
            try convert(buffer: buffer, to: convertedBuffer)
            return convertedBuffer
        } catch {
            throw AudioProcessingError.processingFailed
        }
    }
    
    /// Normalizes audio levels in the buffer
    public func normalizeAudio(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let outputBuffer = createBuffer(like: buffer) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Process each channel
        for channel in 0..<Int(buffer.format.channelCount) {
            guard let inputData = buffer.floatChannelData?[channel],
                  let outputData = outputBuffer.floatChannelData?[channel] else {
                continue
            }
            
            // Find peak amplitude
            var peak: Float = 0
            vDSP_maxmgv(inputData, 1, &peak, vDSP_Length(frameCount))
            
            if peak > 0 {
                // Normalize to peak amplitude of 1.0
                var scale = Float(1.0) / peak
                vDSP_vsmul(inputData, 1, &scale, outputData, 1, vDSP_Length(frameCount))
            } else {
                // If no signal, just copy
                memcpy(outputData, inputData, frameCount * MemoryLayout<Float>.size)
            }
        }
        
        outputBuffer.frameLength = buffer.frameLength
        return outputBuffer
    }
    
    /// Removes silent segments from audio
    public func removeSilence(from buffer: AVAudioPCMBuffer, threshold: Float = 0.02) throws -> AVAudioPCMBuffer {
        let frameCount = Int(buffer.frameLength)
        var activeFrames: [Float] = []
        
        // Process first channel only (mono)
        guard let inputData = buffer.floatChannelData?[0] else {
            throw AudioProcessingError.invalidBuffer
        }
        
        // Detect non-silent frames
        for i in 0..<frameCount {
            let sample = abs(inputData[i])
            if sample > threshold {
                activeFrames.append(inputData[i])
            }
        }
        
        // Create output buffer
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: AVAudioFrameCount(activeFrames.count)) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        // Copy active frames
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            throw AudioProcessingError.invalidBuffer
        }
        
        activeFrames.withUnsafeBufferPointer { ptr in
            memcpy(outputData, ptr.baseAddress!, activeFrames.count * MemoryLayout<Float>.size)
        }
        
        outputBuffer.frameLength = AVAudioFrameCount(activeFrames.count)
        return outputBuffer
    }
    
    /// Detects speech segments in audio
    public func detectSpeechSegments(in buffer: AVAudioPCMBuffer, minimumDuration: TimeInterval = 0.5) throws -> [TimeRange] {
        let frameCount = Int(buffer.frameLength)
        guard let inputData = buffer.floatChannelData?[0] else {
            throw AudioProcessingError.invalidBuffer
        }
        
        // Calculate energy levels
        var energyLevels: [Float] = []
        let windowSize = Int(sampleRate * 0.02)  // 20ms windows
        
        for windowStart in stride(from: 0, to: frameCount, by: windowSize) {
            let windowEnd = min(windowStart + windowSize, frameCount)
            var energy: Float = 0
            
            for i in windowStart..<windowEnd {
                energy += inputData[i] * inputData[i]
            }
            
            energyLevels.append(energy / Float(windowEnd - windowStart))
        }
        
        // Detect speech segments using energy thresholding
        let threshold = calculateDynamicThreshold(energyLevels)
        var segments: [TimeRange] = []
        var segmentStart: Int?
        
        for (i, energy) in energyLevels.enumerated() {
            if energy > threshold && segmentStart == nil {
                segmentStart = i
            } else if energy <= threshold && segmentStart != nil {
                let start = Double(segmentStart!) * 0.02
                let end = Double(i) * 0.02
                
                if end - start >= minimumDuration {
                    segments.append(TimeRange(start: start, end: end))
                }
                
                segmentStart = nil
            }
        }
        
        // Handle segment in progress at the end
        if let start = segmentStart {
            let end = Double(energyLevels.count) * 0.02
            if end - Double(start) * 0.02 >= minimumDuration {
                segments.append(TimeRange(start: Double(start) * 0.02, end: end))
            }
        }
        
        return segments
    }
    
    // MARK: - Private Methods
    
    private func convert(buffer source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer) throws {
        let converter = AVAudioConverter(from: source.format, to: destination.format)
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return source
        }
        
        converter?.convert(to: destination, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            throw error
        }
    }
    
    private func createBuffer(like buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        return AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )
    }
    
    private func calculateDynamicThreshold(_ energyLevels: [Float]) -> Float {
        var sortedLevels = energyLevels.sorted()
        let noiseLevel = sortedLevels[Int(Float(sortedLevels.count) * 0.1)]
        let signalLevel = sortedLevels[Int(Float(sortedLevels.count) * 0.9)]
        
        return noiseLevel + (signalLevel - noiseLevel) * 0.2
    }
}

// MARK: - Supporting Types

public struct TimeRange {
    public let start: TimeInterval
    public let end: TimeInterval
    
    public var duration: TimeInterval {
        return end - start
    }
}

public enum AudioProcessingError: Error {
    case bufferCreationFailed
    case invalidBuffer
    case processingFailed
    
    public var localizedDescription: String {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .invalidBuffer:
            return "Invalid audio buffer format or data"
        case .processingFailed:
            return "Audio processing operation failed"
        }
    }
}

private extension AVAudioFormat {
    var standardizedFormat: AVAudioFormat? {
        return AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )
    }
}
