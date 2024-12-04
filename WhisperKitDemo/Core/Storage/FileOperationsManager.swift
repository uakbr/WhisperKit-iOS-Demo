import Foundation

/// Handles file system operations for reading, writing, and managing files
class FileOperationsManager {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.whisperkit.fileoperations", qos: .utility)
    
    // MARK: - Public Methods
    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func writeJSON<T: Encodable>(_ object: T, to url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(object)
                    try data.write(to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileOperationError.writeFailed(error))
                }
            }
        }
    }
    
    func readJSON<T: Decodable>(from url: URL) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let object = try decoder.decode(T.self, from: data)
                    continuation.resume(returning: object)
                } catch {
                    continuation.resume(throwing: FileOperationError.readFailed(error))
                }
            }
        }
    }
    
    func deleteFile(at url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.fileManager.removeItem(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileOperationError.deleteFailed(error))
                }
            }
        }
    }
    
    func listFiles(in directory: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let contents = try self.fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    continuation.resume(returning: contents)
                } catch {
                    continuation.resume(throwing: FileOperationError.listingFailed(error))
                }
            }
        }
    }
    
    func moveFile(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.fileManager.moveItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileOperationError.moveFailed(error))
                }
            }
        }
    }
    
    func copyFile(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileOperationError.copyFailed(error))
                }
            }
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func getFileSize(at url: URL) throws -> UInt64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }
    
    func getFileModificationDate(at url: URL) throws -> Date {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date ?? Date()
    }
    
    // MARK: - Helper Methods
    private func ensureDirectoryExists(at url: URL) throws {
        let directory = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        
        if !fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            try createDirectory(at: directory)
        }
    }
}

// MARK: - Error Types
enum FileOperationError: Error {
    case writeFailed(Error)
    case readFailed(Error)
    case deleteFailed(Error)
    case listingFailed(Error)
    case moveFailed(Error)
    case copyFailed(Error)
    case invalidPath
    
    var localizedDescription: String {
        switch self {
        case .writeFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete file: \(error.localizedDescription)"
        case .listingFailed(let error):
            return "Failed to list directory contents: \(error.localizedDescription)"
        case .moveFailed(let error):
            return "Failed to move file: \(error.localizedDescription)"
        case .copyFailed(let error):
            return "Failed to copy file: \(error.localizedDescription)"
        case .invalidPath:
            return "Invalid file path"
        }
    }
}
