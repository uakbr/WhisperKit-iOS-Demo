import AVFoundation
import Accelerate

/// Implements specialized noise reduction algorithms for cleaner audio input
class NoiseReductionProcessor {
    // MARK: - Properties
    private let fftLength: Int
    private let hopSize: Int
    private let samplesPerFrame: Int
    
    private var noiseProfile: [Float]?
    private var spectralSubtractionFactor: Float = 2.0
    private var noiseGateThreshold: Float = 0.1
    
    private let fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    
    // MARK: - Initialization
    init(fftLength: Int = 2048, hopSize: Int = 512) {
        self.fftLength = fftLength
        self.hopSize = hopSize
        self.samplesPerFrame = fftLength
        
        // Initialize FFT setup
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(fftLength),
            vDSP_DFT_Direction.FORWARD
        )
        
        // Create Hann window
        self.window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Public Methods
    func process(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            throw NoiseReductionError.outputBufferCreationFailed
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        // Process each channel
        for channel in 0..<Int(buffer.format.channelCount) {
            guard let inputData = buffer.floatChannelData?[channel],
                  let outputData = outputBuffer.floatChannelData?[channel] else {
                continue
            }
            
            // Process audio data in overlapping frames
            let frameCount = Int(buffer.frameLength)
            var processedData = [Float](repeating: 0, count: frameCount)
            
            for frameStart in stride(from: 0, to: frameCount - samplesPerFrame, by: hopSize) {
                let frame = Array(UnsafeBufferPointer(
                    start: inputData.advanced(by: frameStart),
                    count: min(samplesPerFrame, frameCount - frameStart)
                ))
                
                let processedFrame = try processFrame(frame)
                
                // Overlap-add the processed frame
                for i in 0..<processedFrame.count {
                    if frameStart + i < processedData.count {
                        processedData[frameStart + i] += processedFrame[i]
                    }
                }
            }
            
            // Copy processed data to output buffer
            memcpy(outputData, processedData, frameCount * MemoryLayout<Float>.size)
        }
        
        return outputBuffer
    }
    
    func calibrateNoiseProfile(from buffer: AVAudioPCMBuffer) throws {
        var accumulator = [Float](repeating: 0, count: fftLength / 2 + 1)
        var frameCount = 0
        
        // Process each channel
        for channel in 0..<Int(buffer.format.channelCount) {
            guard let inputData = buffer.floatChannelData?[channel] else { continue }
            
            let dataCount = Int(buffer.frameLength)
            
            for frameStart in stride(from: 0, to: dataCount - samplesPerFrame, by: hopSize) {
                let frame = Array(UnsafeBufferPointer(
                    start: inputData.advanced(by: frameStart),
                    count: min(samplesPerFrame, dataCount - frameStart)
                ))
                
                let spectrum = try computeSpectrum(frame)
                
                // Accumulate magnitude spectrum
                vDSP_vadd(spectrum, 1, accumulator, 1, &accumulator, 1, vDSP_Length(spectrum.count))
                frameCount += 1
            }
        }
        
        // Average the accumulated spectrum
        if frameCount > 0 {
            var scale = Float(1.0 / Float(frameCount))
            vDSP_vsmul(accumulator, 1, &scale, &accumulator, 1, vDSP_Length(accumulator.count))
            noiseProfile = accumulator
        }
    }
    
    // MARK: - Private Methods
    private func processFrame(_ frame: [Float]) throws -> [Float] {
        // Apply window function
        var windowedFrame = [Float](repeating: 0, count: fftLength)
        vDSP_vmul(frame, 1, window, 1, &windowedFrame, 1, vDSP_Length(frame.count))
        
        // Compute spectrum
        let spectrum = try computeSpectrum(windowedFrame)
        
        // Apply noise reduction
        var processedSpectrum = spectrum
        if let noiseProfile = noiseProfile {
            for i in 0..<processedSpectrum.count {
                let subtraction = spectralSubtractionFactor * noiseProfile[i]
                processedSpectrum[i] = max(processedSpectrum[i] - subtraction, 0)
                
                // Apply noise gate
                if processedSpectrum[i] < noiseGateThreshold {
                    processedSpectrum[i] = 0
                }
            }
        }
        
        // Inverse transform
        return try inverseTransform(processedSpectrum)
    }
    
    private func computeSpectrum(_ frame: [Float]) throws -> [Float] {
        var realPart = frame
        var imagPart = [Float](repeating: 0, count: fftLength)
        
        // Perform FFT
        guard let fftSetup = fftSetup else {
            throw NoiseReductionError.fftSetupFailed
        }
        
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(fftSetup,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!)
            }
        }
        
        // Compute magnitude spectrum
        var magnitudeSpectrum = [Float](repeating: 0, count: fftLength / 2 + 1)
        vDSP_zvmags(&realPart, &imagPart, &magnitudeSpectrum, vDSP_Length(magnitudeSpectrum.count))
        
        return magnitudeSpectrum
    }
    
    private func inverseTransform(_ spectrum: [Float]) throws -> [Float] {
        var realPart = [Float](repeating: 0, count: fftLength)
        var imagPart = [Float](repeating: 0, count: fftLength)
        
        // Reconstruct complex spectrum
        for i in 0..<spectrum.count {
            realPart[i] = spectrum[i]
        }
        
        // Create inverse FFT setup
        guard let inverseSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(fftLength),
            vDSP_DFT_Direction.INVERSE
        ) else {
            throw NoiseReductionError.fftSetupFailed
        }
        defer { vDSP_DFT_DestroySetup(inverseSetup) }
        
        // Perform inverse FFT
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(inverseSetup,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!,
                                realPtr.baseAddress!,
                                imagPtr.baseAddress!)
            }
        }
        
        // Scale the output
        var scale = Float(1.0 / Float(fftLength))
        vDSP_vsmul(realPart, 1, &scale, &realPart, 1, vDSP_Length(fftLength))
        
        return Array(realPart)
    }
    
    // MARK: - Configuration
    func setSpectralSubtractionFactor(_ factor: Float) {
        spectralSubtractionFactor = max(1.0, min(factor, 4.0))
    }
    
    func setNoiseGateThreshold(_ threshold: Float) {
        noiseGateThreshold = max(0.0, min(threshold, 1.0))
    }
}

// MARK: - Error Types
enum NoiseReductionError: Error {
    case outputBufferCreationFailed
    case fftSetupFailed
    case processingFailed
    
    var localizedDescription: String {
        switch self {
        case .outputBufferCreationFailed:
            return "Failed to create output buffer for noise reduction"
        case .fftSetupFailed:
            return "Failed to initialize FFT setup"
        case .processingFailed:
            return "Noise reduction processing failed"
        }
    }
}
