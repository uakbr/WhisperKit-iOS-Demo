import Foundation
import AVFoundation
import Accelerate

/// General audio processing utilities
class AudioProcessor {
    // MARK: - Properties
    private let bufferSize: AVAudioFrameCount = 4096
    private var fftSetup: vDSP_DFT_Setup?
    
    // Audio settings
    private let sampleRate: Double = 16000  // WhisperKit requirement
    private let channelCount: AVAudioChannelCount = 1
    
    // MARK: - Initialization
    init() {
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
    func normalizeAudio(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
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
    
    func removeSilence(from buffer: AVAudioPCMBuffer, threshold: Float = 0.02) throws -> AVAudioPCMBuffer {
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
    
    func detectSpeechSegments(in buffer: AVAudioPCMBuffer, minimumDuration: TimeInterval = 0.5) throws -> [TimeRange] {
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
struct TimeRange {
    let start: TimeInterval
    let end: TimeInterval
    
    var duration: TimeInterval {
        return end - start
    }
}

enum AudioProcessingError: Error {
    case bufferCreationFailed
    case invalidBuffer
    case processingFailed
    
    var localizedDescription: String {
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
