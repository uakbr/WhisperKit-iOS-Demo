import AVFoundation
import Foundation

/// Handles audio format conversion for compatibility with WhisperKit
class AudioFormatConverter {
    // MARK: - Properties
    private let outputFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    
    // MARK: - Initialization
    init() {
        // Initialize with WhisperKit-compatible format
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }
    
    // MARK: - Conversion Methods
    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Check if conversion is needed
        if buffer.format.isEqual(outputFormat) {
            return buffer
        }
        
        // Create converter if needed
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: outputFormat)
        }
        
        guard let converter = converter else {
            throw AudioConversionError.converterInitializationFailed
        }
        
        // Create output buffer
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw AudioConversionError.outputBufferCreationFailed
        }
        
        // Perform conversion
        var error: NSError?
        let status = converter.convert(to: outputBuffer,
                                     error: &error,
                                     withInputFrom: { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        })
        
        if let error = error {
            throw AudioConversionError.conversionFailed(error)
        }
        
        guard status != .error else {
            throw AudioConversionError.conversionFailed(nil)
        }
        
        return outputBuffer
    }
    
    func convertFile(at url: URL) throws -> URL {
        // Load audio file
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw AudioConversionError.fileReadError
        }
        
        // Create output file URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        // Create output audio file
        guard let outputFile = try? AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings
        ) else {
            throw AudioConversionError.fileWriteError
        }
        
        // Create converter
        guard let converter = AVAudioConverter(
            from: audioFile.processingFormat,
            to: outputFormat
        ) else {
            throw AudioConversionError.converterInitializationFailed
        }
        
        // Create buffer for reading
        let frameCount = 4096
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw AudioConversionError.inputBufferCreationFailed
        }
        
        // Create buffer for writing
        let ratio = outputFormat.sampleRate / audioFile.processingFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(frameCount) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw AudioConversionError.outputBufferCreationFailed
        }
        
        // Perform conversion
        while audioFile.framePosition < audioFile.length {
            do {
                try audioFile.read(into: inputBuffer)
                
                var error: NSError?
                let status = converter.convert(
                    to: outputBuffer,
                    error: &error,
                    withInputFrom: { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return inputBuffer
                    }
                )
                
                if let error = error {
                    throw AudioConversionError.conversionFailed(error)
                }
                
                guard status != .error else {
                    throw AudioConversionError.conversionFailed(nil)
                }
                
                try outputFile.write(from: outputBuffer)
            } catch {
                throw AudioConversionError.conversionFailed(error as NSError)
            }
        }
        
        return outputURL
    }
}

// MARK: - Error Types
enum AudioConversionError: Error {
    case converterInitializationFailed
    case inputBufferCreationFailed
    case outputBufferCreationFailed
    case conversionFailed(NSError?)
    case fileReadError
    case fileWriteError
    
    var localizedDescription: String {
        switch self {
        case .converterInitializationFailed:
            return "Failed to initialize audio converter"
        case .inputBufferCreationFailed:
            return "Failed to create input buffer"
        case .outputBufferCreationFailed:
            return "Failed to create output buffer"
        case .conversionFailed(let error):
            return "Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")"
        case .fileReadError:
            return "Failed to read audio file"
        case .fileWriteError:
            return "Failed to write audio file"
        }
    }
}
