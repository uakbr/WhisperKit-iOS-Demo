import Foundation

/// Captures and logs crash details for debugging
class CrashReporter {
    // MARK: - Properties
    private let fileManager = FileOperationsManager()
    private let crashLogsDirectory: URL
    private let maxCrashLogs = 10
    
    // Configuration
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    
    // MARK: - Initialization
    init() throws {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CrashReporterError.initializationFailed
        }
        
        crashLogsDirectory = documents.appendingPathComponent("CrashLogs")
        try fileManager.createDirectory(at: crashLogsDirectory)
        
        setupCrashHandling()
    }
    
    // MARK: - Public Methods
    func logCrash(_ error: Error, context: [String: Any]? = nil) async throws {
        let crashLog = CrashLog(
            timestamp: Date(),
            error: error,
            context: context,
            deviceInfo: collectDeviceInfo()
        )
        
        try await saveCrashLog(crashLog)
        try await pruneOldLogs()
    }
    
    func getCrashLogs() async throws -> [CrashLog] {
        let files = try await fileManager.listFiles(in: crashLogsDirectory)
        
        return try await withThrowingTaskGroup(of: CrashLog?.self) { group in
            for file in files where file.pathExtension == "json" {
                group.addTask {
                    return try? await self.fileManager.readJSON(from: file)
                }
            }
            
            var logs: [CrashLog] = []
            for try await log in group {
                if let log = log {
                    logs.append(log)
                }
            }
            
            return logs.sorted(by: { $0.timestamp > $1.timestamp })
        }
    }
    
    func clearCrashLogs() async throws {
        let files = try await fileManager.listFiles(in: crashLogsDirectory)
        for file in files {
            try await fileManager.deleteFile(at: file)
        }
    }
    
    // MARK: - Private Methods
    private func setupCrashHandling() {
        NSSetUncaughtExceptionHandler { exception in
            Task {
                try? await self.handleUncaughtException(exception)
            }
        }
    }
    
    private func handleUncaughtException(_ exception: NSException) async throws {
        let error = NSError(
            domain: exception.name.rawValue,
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown reason",
                "callStackSymbols": exception.callStackSymbols,
                "callStackReturnAddresses": exception.callStackReturnAddresses
            ]
        )
        
        try await logCrash(error)
    }
    
    private func saveCrashLog(_ crashLog: CrashLog) async throws {
        let filename = "crash_\(dateFormatter.string(from: crashLog.timestamp)).json"
        let fileURL = crashLogsDirectory.appendingPathComponent(filename)
        
        try await fileManager.writeJSON(crashLog, to: fileURL)
    }
    
    private func pruneOldLogs() async throws {
        let files = try await fileManager.listFiles(in: crashLogsDirectory)
        let sortedFiles = files.sorted { url1, url2 in
            let date1 = try? fileManager.getFileModificationDate(at: url1)
            let date2 = try? fileManager.getFileModificationDate(at: url2)
            return date1 ?? Date.distantPast > date2 ?? Date.distantPast
        }
        
        if sortedFiles.count > maxCrashLogs {
            let filesToDelete = sortedFiles[maxCrashLogs...]
            for file in filesToDelete {
                try await fileManager.deleteFile(at: file)
            }
        }
    }
    
    private func collectDeviceInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        let device = UIDevice.current
        info["model"] = device.model
        info["systemName"] = device.systemName
        info["systemVersion"] = device.systemVersion
        info["identifierForVendor"] = device.identifierForVendor?.uuidString
        
        let screen = UIScreen.main
        info["screenScale"] = String(screen.scale)
        info["screenBounds"] = NSCoder.string(for: screen.bounds)
        
        info["localeIdentifier"] = Locale.current.identifier
        info["timeZoneIdentifier"] = TimeZone.current.identifier
        
        let processInfo = ProcessInfo.processInfo
        info["processorCount"] = String(processInfo.processorCount)
        info["physicalMemory"] = String(processInfo.physicalMemory)
        info["systemUptime"] = String(processInfo.systemUptime)
        
        return info
    }
}

// MARK: - Supporting Types
struct CrashLog: Codable {
    let timestamp: Date
    let errorDomain: String
    let errorCode: Int
    let errorDescription: String
    let context: [String: AnyCodable]?
    let deviceInfo: [String: String]
    
    init(timestamp: Date, error: Error, context: [String: Any]?, deviceInfo: [String: String]) {
        self.timestamp = timestamp
        
        let nsError = error as NSError
        self.errorDomain = nsError.domain
        self.errorCode = nsError.code
        self.errorDescription = nsError.localizedDescription
        
        self.context = context?.mapValues { AnyCodable($0) }
        self.deviceInfo = deviceInfo
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unable to encode value"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

enum CrashReporterError: Error {
    case initializationFailed
    case logSaveFailed
    case invalidLogFormat
    
    var localizedDescription: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize crash reporter"
        case .logSaveFailed:
            return "Failed to save crash log"
        case .invalidLogFormat:
            return "Invalid crash log format"
        }
    }
}
