import AVFoundation
import Accelerate

/// Handles audio enhancement and effects processing
class AudioEffectsProcessor {
    // MARK: - Properties
    private let fftSetup: vDSP_DFT_Setup?
    private let maxFramesPerBuffer: Int
    private var window: [Float]
    
    // Effect settings
    private var noiseFloor: Float = 0.01
    private var gainValue: Float = 1.0
    
    // MARK: - Initialization
    init(maxFramesPerBuffer: Int = 4096) {
        self.maxFramesPerBuffer = maxFramesPerBuffer
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(maxFramesPerBuffer),
            vDSP_DFT_Direction.FORWARD
        )
        
        // Create Hanning window for FFT
        self.window = [Float](repeating: 0, count: maxFramesPerBuffer)
        vDSP_hann_window(&window, vDSP_Length(maxFramesPerBuffer), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Public Methods
    func process(_ buffer: AVAudioPCMBuffer, options: AudioProcessingOptions = .default) throws -> AVAudioPCMBuffer {
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            throw AudioProcessingError.outputBufferCreationFailed
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        // Process each channel
        for channel in 0..<Int(buffer.format.channelCount) {
            guard let inputData = buffer.floatChannelData?[channel],
                  let outputData = outputBuffer.floatChannelData?[channel] else {
                continue
            }
            
            // Apply selected processing options
            var processedData = Array(UnsafeBufferPointer(start: inputData, count: Int(buffer.frameLength)))
            
            if options.contains(.noiseReduction) {
                applyNoiseReduction(&processedData)
            }
            
            if options.contains(.normalization) {
                normalizeAudio(&processedData)
            }
            
            if options.contains(.gain) {
                applyGain(&processedData)
            }
            
            // Copy processed data back to output buffer
            memcpy(outputData, processedData, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
        
        return outputBuffer
    }
    
    // MARK: - Processing Methods
    private func applyNoiseReduction(_ data: inout [Float]) {
        guard data.count <= maxFramesPerBuffer else { return }
        
        var realPart = [Float](repeating: 0, count: maxFramesPerBuffer)
        var imagPart = [Float](repeating: 0, count: maxFramesPerBuffer)
        
        // Apply window function
        vDSP_vmul(data, 1, window, 1, &realPart, 1, vDSP_Length(data.count))
        
        // Perform FFT
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                guard let fftSetup = fftSetup else { return }
                vDSP_DFT_Execute(fftSetup,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!)
            }
        }
        
        // Apply noise reduction in frequency domain
        for i in 0..<maxFramesPerBuffer {
            let magnitude = sqrt(realPart[i] * realPart[i] + imagPart[i] * imagPart[i])
            if magnitude < noiseFloor {
                realPart[i] = 0
                imagPart[i] = 0
            }
        }
        
        // Inverse FFT
        let inverseSetup = vDSP_DFT_zop_CreateSetup(nil,
                                                    UInt(maxFramesPerBuffer),
                                                    vDSP_DFT_Direction.INVERSE)
        defer { vDSP_DFT_DestroySetup(inverseSetup) }
        
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(inverseSetup!,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!)
            }
        }
        
        // Scale output
        var scale = Float(1.0 / Float(maxFramesPerBuffer))
        vDSP_vsmul(realPart, 1, &scale, &data, 1, vDSP_Length(data.count))
    }
    
    private func normalizeAudio(_ data: inout [Float]) {
        var max: Float = 0
        vDSP_maxmgv(data, 1, &max, vDSP_Length(data.count))
        
        if max > 0 {
            var scale = Float(1.0) / max
            vDSP_vsmul(data, 1, &scale, &data, 1, vDSP_Length(data.count))
        }
    }
    
    private func applyGain(_ data: inout [Float]) {
        vDSP_vsmul(data, 1, &gainValue, &data, 1, vDSP_Length(data.count))
    }
    
    // MARK: - Configuration Methods
    func setGain(_ gain: Float) {
        gainValue = max(0, min(gain, 2.0)) // Limit gain to reasonable range
    }
    
    func setNoiseFloor(_ floor: Float) {
        noiseFloor = max(0, min(floor, 0.1)) // Limit noise floor to reasonable range
    }
}

// MARK: - Supporting Types
struct AudioProcessingOptions: OptionSet {
    let rawValue: Int
    
    static let noiseReduction = AudioProcessingOptions(rawValue: 1 << 0)
    static let normalization = AudioProcessingOptions(rawValue: 1 << 1)
    static let gain = AudioProcessingOptions(rawValue: 1 << 2)
    
    static let `default`: AudioProcessingOptions = [.noiseReduction, .normalization]
}

enum AudioProcessingError: Error {
    case outputBufferCreationFailed
    case processingFailed
    
    var localizedDescription: String {
        switch self {
        case .outputBufferCreationFailed:
            return "Failed to create output buffer for audio processing"
        case .processingFailed:
            return "Audio processing operation failed"
        }
    }
}
