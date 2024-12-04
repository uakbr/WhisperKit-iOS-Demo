//
// AudioModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

/// Model class representing the audio state and operations
public class AudioModel: ObservableObject {
    
    // MARK: - Properties
    
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let fileManager: FileManaging
    private let errorManager: ErrorHandling
    private let logger: Logging
    
    private var audioFile: AVAudioFile?
    private var displayLink: CADisplayLink?
    private var needsFileScheduled = true
    private var audioFileDuration: TimeInterval = 0
    
    @Published private(set) var isPlaying = false
    @Published private(set) var isRecording = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var audioURL: URL?
    
    // MARK: - Initialization
    
    init(fileManager: FileManaging,
         errorManager: ErrorHandling,
         logger: Logging) {
        self.fileManager = fileManager
        self.errorManager = errorManager
        self.logger = logger.scoped(for: "AudioModel")
        
        setupAudioSession()
        setupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// Starts recording audio
    public func startRecording() {
        guard !isRecording else { return }
        
        do {
            let format = engine.inputNode.outputFormat(forBus: 0)
            let fileName = AudioFileManager.generateUniqueFileName()
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsPath.appendingPathComponent(fileName)
            
            audioFile = try AVAudioFile(forWriting: outputURL,
                                       settings: format.settings)
            
            engine.inputNode.installTap(onBus: 0,
                                       bufferSize: 1024,
                                       format: format) { [weak self] buffer, time in
                guard let self = self else { return }
                
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    self.errorManager.handle(.audioStreamError("Failed to write audio buffer: \(error.localizedDescription)"))
                }
            }
            
            try engine.start()
            isRecording = true
            audioURL = outputURL
            logger.info("Started recording to file: \(fileName)")
            
        } catch {
            errorManager.handle(.audioStreamError("Failed to start recording: \(error.localizedDescription)"))
        }
    }
    
    /// Stops recording audio
    public func stopRecording() {
        guard isRecording else { return }
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        isRecording = false
        
        logger.info("Stopped recording")
    }
    
    /// Loads an audio file for playback
    /// - Parameter url: URL of the audio file to load
    public func loadAudio(from url: URL) {
        do {
            stopPlayback()
            
            audioFile = try AVAudioFile(forReading: url)
            audioURL = url
            audioFileDuration = Double(audioFile?.length ?? 0) / audioFile?.processingFormat.sampleRate ?? 44100.0
            needsFileScheduled = true
            
            logger.info("Loaded audio file: \(url.lastPathComponent)")
        } catch {
            errorManager.handle(.audioStreamError("Failed to load audio file: \(error.localizedDescription)"))
        }
    }
    
    /// Starts audio playback
    public func startPlayback() {
        guard !isPlaying, let audioFile = audioFile else { return }
        
        do {
            if !engine.isRunning {
                try engine.start()
            }
            
            if needsFileScheduled {
                player.scheduleFile(audioFile, at: nil)
                needsFileScheduled = false
            }
            
            player.play()
            isPlaying = true
            startPlaybackTimeObserver()
            
            logger.info("Started playback")
        } catch {
            errorManager.handle(.audioStreamError("Failed to start playback: \(error.localizedDescription)"))
        }
    }
    
    /// Pauses audio playback
    public func pausePlayback() {
        guard isPlaying else { return }
        
        player.pause()
        isPlaying = false
        stopPlaybackTimeObserver()
        
        logger.info("Paused playback")
    }
    
    /// Stops audio playback
    public func stopPlayback() {
        player.stop()
        isPlaying = false
        currentTime = 0
        needsFileScheduled = true
        stopPlaybackTimeObserver()
        
        logger.info("Stopped playback")
    }
    
    /// Seeks to a specific time in the audio
    /// - Parameter time: Time to seek to in seconds
    public func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let wasPlaying = isPlaying
        stopPlayback()
        
        let framePosition = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        player.scheduleSegment(
            audioFile,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(audioFile.length - framePosition),
            at: nil
        )
        needsFileScheduled = false
        currentTime = time
        
        if wasPlaying {
            startPlayback()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                          mode: .default,
                                                          options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorManager.handle(.audioStreamError("Failed to setup audio session: \(error.localizedDescription)"))
        }
    }
    
    private func setupAudioEngine() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }
    
    private func startPlaybackTimeObserver() {
        stopPlaybackTimeObserver()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopPlaybackTimeObserver() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updatePlaybackTime() {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return
        }
        
        currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        
        if currentTime >= audioFileDuration {
            stopPlayback()
        }
    }
    
    deinit {
        stopPlayback()
        stopRecording()
        engine.stop()
    }
}
