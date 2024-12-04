import AVFoundation
import Combine
import Foundation

/// Manages real-time audio input streaming for the WhisperKit transcription pipeline
class AudioStreamManager: ObservableObject {
    // MARK: - Properties
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private let bufferSize: AVAudioFrameCount = 4096
    private var audioFormat: AVAudioFormat?
    
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0
    
    // Audio processing chain
    private var cancellables = Set<AnyCancellable>()
    private let audioProcessingQueue = DispatchQueue(label: "com.whisperkit.audioprocessing")
    
    // Completion handler for processed audio
    var onAudioData: ((AVAudioPCMBuffer) -> Void)?
    
    // MARK: - Initialization
    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        setupAudioFormat()
        setupNotifications()
    }
    
    // MARK: - Setup Methods
    private func setupAudioFormat() {
        // Configure audio format for WhisperKit compatibility
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000, // WhisperKit expected sample rate
            channels: 1,
            interleaved: false
        )
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func startRecording() throws {
        guard !isRecording else { return }
        
        do {
            try setupAudioSession()
            try setupAudioTap()
            try audioEngine.start()
            isRecording = true
        } catch {
            throw AudioStreamError.recordingFailed(error)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isRecording = false
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true)
    }
    
    private func setupAudioTap() throws {
        guard let format = audioFormat else {
            throw AudioStreamError.invalidFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Calculate audio level for UI feedback
        if let channelData = buffer.floatChannelData?[0] {
            let length = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<length {
                sum += abs(channelData[i])
            }
            let average = sum / Float(length)
            DispatchQueue.main.async {
                self.audioLevel = average
            }
        }
        
        // Process audio data on background queue
        audioProcessingQueue.async { [weak self] in
            self?.onAudioData?(buffer)
        }
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            stopRecording()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                  let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue),
                  options.contains(.shouldResume) else {
                return
            }
            try? startRecording()
        @unknown default:
            break
        }
    }
}

// MARK: - Error Types
enum AudioStreamError: Error {
    case invalidFormat
    case recordingFailed(Error)
    case sessionSetupFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidFormat:
            return "Invalid audio format configuration"
        case .recordingFailed(let error):
            return "Failed to start recording: \(error.localizedDescription)"
        case .sessionSetupFailed(let error):
            return "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
}

// MARK: - AudioStreamManager Delegate Protocol
protocol AudioStreamManagerDelegate: AnyObject {
    func audioStreamManager(_ manager: AudioStreamManager, didReceiveBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime)
    func audioStreamManager(_ manager: AudioStreamManager, didEncounterError error: Error)
}