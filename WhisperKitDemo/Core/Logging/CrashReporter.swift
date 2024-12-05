import Foundation
import UIKit

/// Reports and handles application crashes and critical errors
class CrashReporter {
    private let logger: Logging
    private let deviceInfo: DeviceInfo
    
    init(logger: Logging? = nil) {
        self.logger = logger ?? LoggingManager(category: "CrashReporter")
        self.deviceInfo = DeviceInfo()
    }
    
    func log(_ error: Error) {
        let report = generateErrorReport(error)
        logger.error(report)
    }
    
    func logCriticalFailure(_ error: Error) {
        let report = generateCrashReport(error)
        logger.critical(report)
    }
    
    private func generateErrorReport(_ error: Error) -> String {
        var report = ""
        report += "Error: \(error.localizedDescription)\n"
        report += "Time: \(Date())\n"
        report += deviceInfo.summary
        return report
    }
    
    private func generateCrashReport(_ error: Error) -> String {
        var report = ""
        report += "‼️ CRITICAL ERROR ‼️\n"
        report += "Type: \(type(of: error))\n"
        report += "Description: \(error.localizedDescription)\n"
        report += "Time: \(Date())\n\n"
        report += "Device Information:\n"
        report += deviceInfo.detailedSummary
        return report
    }
}

/// Collects device-specific information
private struct DeviceInfo {
    let device: UIDevice
    let screen: UIScreen
    
    init() {
        self.device = .current
        self.screen = .main
    }
    
    var summary: String {
        return "\(device.systemName) \(device.systemVersion) | \(device.model)"
    }
    
    var detailedSummary: String {
        var info = ""
        info += "Device: \(device.model)\n"
        info += "System: \(device.systemName) \(device.systemVersion)\n"
        info += "Screen: \(screen.bounds.size.width)x\(screen.bounds.size.height) @\(screen.scale)x\n"
        info += "Memory: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB\n"
        info += "Processors: \(ProcessInfo.processInfo.processorCount)\n"
        return info
    }
}
