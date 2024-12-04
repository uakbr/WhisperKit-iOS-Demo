import AVFoundation
import Combine

/// Manages audio session configuration and handling
class AudioSessionManager {
    // MARK: - Properties
    private let session = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    // State tracking
    private(set) var isSessionActive = false
    private(set) var currentRoute: AVAudioSessionRouteDescription?
    
    // Callbacks
    var onRouteChange: ((AVAudioSessionRouteChangeReason) -> Void)?
    var onInterruption: ((AVAudioSession.InterruptionType) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func configureSession() throws {
        do {
            // Configure for recording with maximum quality
            try session.setCategory(.playAndRecord,
                                  mode: .measurement,
                                  options: [.allowBluetooth, .defaultToSpeaker])
            
            // Set preferred sample rate and I/O buffer duration
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer
            
            // Apply configuration
            try session.setActive(true)
            isSessionActive = true
            
            // Store current route
            currentRoute = session.currentRoute
        } catch {
            throw AudioSessionError.configurationFailed(error)
        }
    }
    
    func deactivateSession() throws {
        guard isSessionActive else { return }
        
        do {
            try session.setActive(false)
            isSessionActive = false
        } catch {
            throw AudioSessionError.deactivationFailed(error)
        }
    }
    
    func requestRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func getCurrentInputDevice() -> AVAudioSessionPortDescription? {
        return session.currentRoute.inputs.first
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        // Monitor route changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
        
        // Monitor interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Monitor media reset
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                self?.handleMediaReset()
            }
            .store(in: &cancellables)
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Update current route
        currentRoute = session.currentRoute
        
        // Handle specific route changes
        switch reason {
        case .oldDeviceUnavailable:
            handleDeviceDisconnection()
        case .newDeviceAvailable:
            handleDeviceConnection()
        case .categoryChange:
            handleCategoryChange()
        default:
            break
        }
        
        onRouteChange?(reason)
    }
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            handleInterruptionBegan()
        case .ended:
            handleInterruptionEnded(notification)
        @unknown default:
            break
        }
        
        onInterruption?(type)
    }
    
    private func handleInterruptionBegan() {
        // Handle interruption start
        isSessionActive = false
    }
    
    private func handleInterruptionEnded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
            return
        }
        
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
            try? configureSession()
        }
    }
    
    private func handleMediaReset() {
        // Reconfigure audio session after media server reset
        try? configureSession()
    }
    
    private func handleDeviceConnection() {
        // Handle new audio device connection
        if let input = getCurrentInputDevice() {
            updateAudioConfiguration(for: input)
        }
    }
    
    private func handleDeviceDisconnection() {
        // Handle audio device disconnection
        try? configureSession()
    }
    
    private func handleCategoryChange() {
        // Handle audio session category change
        try? configureSession()
    }
    
    private func updateAudioConfiguration(for input: AVAudioSessionPortDescription) {
        // Update configuration based on input device
        let dataSources = input.dataSources ?? []
        if let preferredDataSource = dataSources.first(where: { $0.supportedPolarPatterns?.contains(.stereo) ?? false }) {
            try? input.setPreferredDataSource(preferredDataSource)
        }
    }
}

// MARK: - Error Types
enum AudioSessionError: Error {
    case configurationFailed(Error)
    case deactivationFailed(Error)
    case noInputAvailable
    
    var localizedDescription: String {
        switch self {
        case .configurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "Failed to deactivate audio session: \(error.localizedDescription)"
        case .noInputAvailable:
            return "No audio input device available"
        }
    }
}
