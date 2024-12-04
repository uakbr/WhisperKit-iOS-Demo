//
// AudioProcessor.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import AVFoundation

enum AudioProcessingError: Error {
    case bufferCreationFailed(String)
    case invalidBuffer(String)
    case conversionFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .bufferCreationFailed(let message):
            return "Failed to create audio buffer: \(message)"
        case .invalidBuffer(let message):
            return "Invalid audio buffer: \(message)"
        case .conversionFailed(let message):
            return "Audio conversion failed: \(message)"
        }
    }
}

class AudioProcessor {
    private let audioEngine: AVAudioEngine
    private let errorManager: ErrorHandling
    
    init(audioEngine: AVAudioEngine, errorManager: ErrorHandling) {
        self.audioEngine = audioEngine
        self.errorManager = errorManager
    }
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let format = buffer.format.standardizedFormat else {
            throw AudioProcessingError.invalidBuffer("Buffer format cannot be standardized")
        }
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: buffer.frameLength
        ) else {
            throw AudioProcessingError.bufferCreationFailed("Could not create converted buffer")
        }
        
        do {
            try convert(buffer: buffer, to: convertedBuffer)
            return convertedBuffer
        } catch {
            throw AudioProcessingError.conversionFailed(error.localizedDescription)
        }
    }
    
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
}

private extension AVAudioFormat {
    var standardizedFormat: AVAudioFormat? {
        return AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )
    }
}
