//
// WhisperModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation
import WhisperKit

/// Represents a Whisper model configuration and metadata
public struct WhisperModel: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let type: ModelType
    public let version: String
    public let fileSize: Int64
    public let url: URL
    public let checksum: String?
    
    public enum ModelType: String, Codable {
        case tiny
        case base
        case small
        case medium
        case large
        
        var memoryRequirement: Int64 {
            switch self {
            case .tiny: return 256 * 1024 * 1024     // 256MB
            case .base: return 512 * 1024 * 1024     // 512MB
            case .small: return 1024 * 1024 * 1024   // 1GB
            case .medium: return 2.5 * 1024 * 1024 * 1024  // 2.5GB
            case .large: return 5 * 1024 * 1024 * 1024    // 5GB
            }
        }
        
        var processingSpeedMultiplier: Double {
            switch self {
            case .tiny: return 5.0
            case .base: return 4.0
            case .small: return 2.0
            case .medium: return 1.0
            case .large: return 0.5
            }
        }
    }
}
