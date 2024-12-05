import Foundation
import os.log

/// Protocol defining logging capabilities
protocol Logging {
    func log(_ message: String, level: LogLevel)
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func critical(_ message: String)
    func scoped(category: String) -> Logging
}

/// Log levels with associated emojis and system log types
enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// Manager class responsible for centralized logging
class LoggingManager: Logging {
    private let subsystem: String
    private var category: String
    private let osLog: OSLog
    
    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.whisperkit.demo",
         category: String = "default") {
        self.subsystem = subsystem
        self.category = category
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    func log(_ message: String, level: LogLevel) {
        os_log("%{public}@ %{public}@",
               log: osLog,
               type: level.osLogType,
               level.emoji,
               message)
    }
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func critical(_ message: String) {
        log(message, level: .critical)
    }
    
    func scoped(category: String) -> Logging {
        LoggingManager(subsystem: subsystem, category: category)
    }
}
