import Foundation
import UIKit
import Combine

/// Enhances UI accessibility features and manages accessibility settings
class AccessibilityManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var isVoiceOverRunning = false
    @Published private(set) var isSwitchControlRunning = false
    @Published private(set) var preferredContentSizeCategory: UIContentSizeCategory = .large
    @Published private(set) var isReduceMotionEnabled = false
    @Published private(set) var isReduceTransparencyEnabled = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // Default values for accessible text
    private let minimumTouchTargetSize = CGSize(width: 44, height: 44)
    private let defaultButtonFontSize: CGFloat = 18
    private let defaultLabelFontSize: CGFloat = 16
    
    // MARK: - Initialization
    init() {
        setupAccessibilityNotifications()
        updateAccessibilityStates()
    }
    
    // MARK: - Public Methods
    func configureAccessibility(for view: UIView, label: String? = nil, hint: String? = nil, traits: UIAccessibilityTraits? = nil) {
        view.isAccessibilityElement = true
        
        if let label = label {
            view.accessibilityLabel = label
        }
        
        if let hint = hint {
            view.accessibilityHint = hint
        }
        
        if let traits = traits {
            view.accessibilityTraits = traits
        }
        
        // Ensure minimum touch target size
        let currentSize = view.bounds.size
        if currentSize.width < minimumTouchTargetSize.width || currentSize.height < minimumTouchTargetSize.height {
            var newFrame = view.frame
            newFrame.size.width = max(currentSize.width, minimumTouchTargetSize.width)
            newFrame.size.height = max(currentSize.height, minimumTouchTargetSize.height)
            view.frame = newFrame
        }
    }
    
    func accessibleFont(for style: AccessibleFontStyle, size: CGFloat? = nil) -> UIFont {
        let baseSize = size ?? (style == .button ? defaultButtonFontSize : defaultLabelFontSize)
        
        // Scale font size based on user's preferred content size category
        let metrics = UIFontMetrics(forTextStyle: style.textStyle)
        
        if let font = style.font(withSize: baseSize) {
            return metrics.scaledFont(for: font)
        } else {
            return metrics.scaledFont(for: .systemFont(ofSize: baseSize))
        }
    }
    
    func announceChange(_ message: String, delay: TimeInterval = 0.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func postScreenChange() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
    
    func postLayoutChange() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
    
    func groupAccessibilityElements(_ elements: [UIView], in container: UIView) {
        let group = UIAccessibilityElement(accessibilityContainer: container)
        group.accessibilityFrameInContainerSpace = container.bounds
        group.accessibilityElements = elements
        container.accessibilityElements = [group]
    }
    
    // MARK: - Private Methods
    private func setupAccessibilityNotifications() {
        // Monitor VoiceOver status
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilityStates()
            }
            .store(in: &cancellables)
        
        // Monitor Switch Control status
        NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilityStates()
            }
            .store(in: &cancellables)
        
        // Monitor content size changes
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateContentSizeCategory()
            }
            .store(in: &cancellables)
        
        // Monitor reduce motion preference
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilityStates()
            }
            .store(in: &cancellables)
        
        // Monitor transparency preference
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilityStates()
            }
            .store(in: &cancellables)
    }
    
    private func updateAccessibilityStates() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    }
    
    private func updateContentSizeCategory() {
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    }
}

// MARK: - Supporting Types
enum AccessibleFontStyle {
    case button
    case label
    case heading
    case body
    
    var textStyle: UIFont.TextStyle {
        switch self {
        case .button:
            return .headline
        case .label:
            return .body
        case .heading:
            return .title1
        case .body:
            return .body
        }
    }
    
    func font(withSize size: CGFloat) -> UIFont? {
        switch self {
        case .button:
            return .systemFont(ofSize: size, weight: .medium)
        case .label:
            return .systemFont(ofSize: size, weight: .regular)
        case .heading:
            return .systemFont(ofSize: size, weight: .bold)
        case .body:
            return .systemFont(ofSize: size, weight: .regular)
        }
    }
}

// MARK: - View Extension
extension UIView {
    func makeAccessible(label: String? = nil, hint: String? = nil, traits: UIAccessibilityTraits? = nil) {
        AccessibilityManager().configureAccessibility(for: self, label: label, hint: hint, traits: traits)
    }
}
