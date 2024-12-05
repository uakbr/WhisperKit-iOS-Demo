//
// WhisperKitModel.swift
// WhisperKitDemo
//
// Created by Claude on 2024-03-12.
// Copyright © 2024 Anthropic. All rights reserved.
//

import Foundation

public enum WhisperKitModel: String, CaseIterable, Identifiable, Codable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var fileSize: String {
        switch self {
        case .tiny: return "75MB"
        case .base: return "150MB"
        case .small: return "500MB"
        case .medium: return "1.5GB"
        case .large: return "3GB"
        }
    }
    
    var memoryUsage: String {
        switch self {
        case .tiny: return "~256MB"
        case .base: return "~512MB"
        case .small: return "~1GB"
        case .medium: return "~2.5GB"
        case .large: return "~5GB"
        }
    }
    
    var processingSpeed: String {
        switch self {
        case .tiny: return "5x"
        case .base: return "4x"
        case .small: return "2x"
        case .medium: return "1x"
        case .large: return "0.5x"
        }
    }
}
