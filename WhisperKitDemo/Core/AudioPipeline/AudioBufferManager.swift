import AVFoundation
import Foundation

/// Manages audio buffer operations for smooth processing of audio data
class AudioBufferManager {
    // MARK: - Properties
    private let bufferCount: Int
    private let bufferSize: AVAudioFrameCount
    private var audioBuffers: [AVAudioPCMBuffer]
    private var currentBufferIndex: Int = 0
    
    private let queue = DispatchQueue(label: "com.whisperkit.buffer", qos: .userInitiated)
    private let semaphore: DispatchSemaphore
    
    // MARK: - Initialization
    init(bufferCount: Int = 3, bufferSize: AVAudioFrameCount = 4096, format: AVAudioFormat) {
        self.bufferCount = bufferCount
        self.bufferSize = bufferSize
        self.semaphore = DispatchSemaphore(value: bufferCount)
        
        // Initialize audio buffers
        self.audioBuffers = (0..<bufferCount).map { _ in
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        }
    }
    
    // MARK: - Public Methods
    func getNextBuffer() -> AVAudioPCMBuffer? {
        semaphore.wait()
        
        return queue.sync {
            let buffer = audioBuffers[currentBufferIndex]
            currentBufferIndex = (currentBufferIndex + 1) % bufferCount
            return buffer
        }
    }
    
    func releaseBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.sync {
            if let index = audioBuffers.firstIndex(where: { $0 === buffer }) {
                buffer.frameLength = 0  // Clear the buffer
                semaphore.signal()
            }
        }
    }
    
    func copyAudioData(from sourceBuffer: AVAudioPCMBuffer, to destinationBuffer: AVAudioPCMBuffer) throws {
        guard sourceBuffer.format.isEqual(destinationBuffer.format) else {
            throw AudioBufferError.formatMismatch
        }
        
        guard sourceBuffer.frameLength <= destinationBuffer.frameCapacity else {
            throw AudioBufferError.insufficientCapacity
        }
        
        // Copy audio data between buffers
        let frameCount = sourceBuffer.frameLength
        destinationBuffer.frameLength = frameCount
        
        // Copy channel data
        for channel in 0..<Int(sourceBuffer.format.channelCount) {
            guard let srcData = sourceBuffer.floatChannelData?[channel],
                  let dstData = destinationBuffer.floatChannelData?[channel] else {
                continue
            }
            
            memcpy(dstData, srcData, Int(frameCount) * MemoryLayout<Float>.size)
        }
    }
    
    func clearAllBuffers() {
        queue.sync {
            audioBuffers.forEach { buffer in
                buffer.frameLength = 0
            }
            currentBufferIndex = 0
            
            // Reset semaphore
            while semaphore.signal() != 0 {}
            for _ in 0..<bufferCount {
                semaphore.wait()
            }
        }
    }
    
    // MARK: - Buffer Management Methods
    func concatenateBuffers(_ buffers: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer? {
        guard let firstBuffer = buffers.first else { return nil }
        
        // Calculate total frame count
        let totalFrames = buffers.reduce(0) { $0 + $1.frameLength }
        
        // Create new buffer with total capacity
        guard let concatenatedBuffer = AVAudioPCMBuffer(
            pcmFormat: firstBuffer.format,
            frameCapacity: totalFrames
        ) else {
            throw AudioBufferError.bufferCreationFailed
        }
        
        var currentFrame: AVAudioFrameCount = 0
        
        // Copy data from each buffer
        for buffer in buffers {
            guard buffer.format.isEqual(firstBuffer.format) else {
                throw AudioBufferError.formatMismatch
            }
            
            let frameCount = buffer.frameLength
            
            // Copy each channel
            for channel in 0..<Int(buffer.format.channelCount) {
                guard let sourceData = buffer.floatChannelData?[channel],
                      let destData = concatenatedBuffer.floatChannelData?[channel] else {
                    continue
                }
                
                let destinationOffset = destData.advanced(by: Int(currentFrame))
                memcpy(destinationOffset,
                       sourceData,
                       Int(frameCount) * MemoryLayout<Float>.size)
            }
            
            currentFrame += frameCount
        }
        
        concatenatedBuffer.frameLength = totalFrames
        return concatenatedBuffer
    }
}

// MARK: - Error Types
enum AudioBufferError: Error {
    case formatMismatch
    case insufficientCapacity
    case bufferCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .formatMismatch:
            return "Audio format mismatch between buffers"
        case .insufficientCapacity:
            return "Destination buffer has insufficient capacity"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        }
    }
}
