import AVFoundation
import Combine

/// Coordinates audio processing tasks and data flow through the audio pipeline
class AudioProcessingManager: ObservableObject {
    // MARK: - Properties
    private let streamManager: AudioStreamManager
    private let bufferManager: AudioBufferManager
    private let formatConverter: AudioFormatConverter
    private let effectsProcessor: AudioEffectsProcessor
    private let noiseReducer: NoiseReductionProcessor
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    
    // Pipeline configuration
    private var processingOptions: AudioProcessingOptions = .default
    private var useNoiseReduction: Bool = true
    
    // MARK: - Output Handlers
    var onProcessedAudio: ((AVAudioPCMBuffer) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    init() {
        // Initialize components
        streamManager = AudioStreamManager()
        formatConverter = AudioFormatConverter()
        effectsProcessor = AudioEffectsProcessor()
        noiseReducer = NoiseReductionProcessor()
        
        // Initialize buffer manager with WhisperKit-compatible format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        bufferManager = AudioBufferManager(format: format)
        
        setupAudioPipeline()
    }
    
    // MARK: - Public Methods
    func startProcessing() throws {
        guard !isProcessing else { return }
        
        try streamManager.startRecording()
        isProcessing = true
    }
    
    func stopProcessing() {
        guard isProcessing else { return }
        
        streamManager.stopRecording()
        isProcessing = false
    }
    
    func calibrateNoiseProfile(duration: TimeInterval = 2.0) {
        // Temporarily store audio for calibration
        var calibrationBuffer: AVAudioPCMBuffer?
        
        let originalHandler = onProcessedAudio
        onProcessedAudio = { buffer in
            calibrationBuffer = buffer
        }
        
        // Record ambient noise for calibration
        try? startProcessing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopProcessing()
            
            if let buffer = calibrationBuffer {
                try? self?.noiseReducer.calibrateNoiseProfile(from: buffer)
            }
            
            self?.onProcessedAudio = originalHandler
        }
    }
    
    // MARK: - Configuration Methods
    func setProcessingOptions(_ options: AudioProcessingOptions) {
        processingOptions = options
    }
    
    func setNoiseReductionEnabled(_ enabled: Bool) {
        useNoiseReduction = enabled
    }
    
    func setGain(_ gain: Float) {
        effectsProcessor.setGain(gain)
    }
    
    // MARK: - Private Methods
    private func setupAudioPipeline() {
        // Subscribe to audio stream
        streamManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        // Set up audio processing chain
        streamManager.onAudioData = { [weak self] buffer in
            guard let self = self else { return }
            
            do {
                // Convert format if needed
                let convertedBuffer = try self.formatConverter.convert(buffer)
                
                // Apply noise reduction if enabled
                let noiseReducedBuffer = self.useNoiseReduction ?
                    try self.noiseReducer.process(convertedBuffer) :
                    convertedBuffer
                
                // Apply audio effects
                let processedBuffer = try self.effectsProcessor.process(
                    noiseReducedBuffer,
                    options: self.processingOptions
                )
                
                // Get next available buffer from pool
                if let outputBuffer = self.bufferManager.getNextBuffer() {
                    try self.bufferManager.copyAudioData(from: processedBuffer, to: outputBuffer)
                    
                    // Notify completion
                    DispatchQueue.main.async {
                        self.onProcessedAudio?(outputBuffer)
                        self.bufferManager.releaseBuffer(outputBuffer)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopProcessing()
        cancellables.removeAll()
    }
}

// MARK: - Error Types
enum AudioProcessingError: Error {
    case pipelineError(Error)
    case bufferError
    
    var localizedDescription: String {
        switch self {
        case .pipelineError(let error):
            return "Audio pipeline error: \(error.localizedDescription)"
        case .bufferError:
            return "Buffer management error in audio pipeline"
        }
    }
}
