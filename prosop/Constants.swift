//
//  Constants.swift
//  Prosop
//
//  Created by Arvat Vladimir on 15.03.2026.
//

import Foundation
import SwiftUI

// MARK: - Storage Keys
enum StorageKeys {
    static let openAISecretKey = "openAISecretKey"
    static let hasAcceptedAITerms = "hasAcceptedAITerms"
    static let isVoiceAnswerEnabled = "isVoiceAnswerEnabled"
    static let aiPreferredLanguage = "aiPreferredLanguage"
    static let showAIButtons = "showAIButtons"
}

// MARK: - UI Constants
enum UIConstants {
    // Spacing
    static let standardSpacing: CGFloat = 16
    static let actionButtonSpacing: CGFloat = 40
    static let cardSpacing: CGFloat = 12
    
    // Offsets
    static let overlayIconOffset = CGSize(width: 10, height: -10)
    
    // Sizes
    static let thumbnailSize: CGFloat = 50
    static let photoPreviewSize: CGFloat = 120
    static let iconSize: CGFloat = 30
    
    // Padding
    static let cardPadding: CGFloat = 24
    static let buttonPadding: CGFloat = 32
    
    // Corner Radius
    static let standardCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let thumbnailCornerRadius: CGFloat = 8
    
    // Opacity
    static let disabledOpacity: CGFloat = 0.5
    static let checkedOpacity: CGFloat = 0.5
}

// MARK: - AI Configuration
enum AIConfiguration {
    static let supportedLanguages = [
        "English",
        "Romanian", 
        "Russian",
        "Ukrainian",
        "French",
        "German",
        "Spanish",
        "Italian"
    ]
    
    static let confirmableActions = [
        "ADD_CATEGORY",
        "ADD_ITEMS",
        "DELETE_ITEMS",
        "DELETE_CATEGORY",
        "UPDATE_CATEGORY",
        "UPDATE_ITEMS"
    ]
    
    static let defaultAnalysisPrompt = "Analyze this photo. If it contains items, categorize them and add them to my inventory."
}

// MARK: - Database Configuration
enum DatabaseConfiguration {
    static let databaseName = "InventoryDB.sqlite"
    static let currentSchemaVersion: Int32 = 1
}

// MARK: - Image Configuration
enum ImageConfiguration {
    static let maxPhotoSizeKB = 500
    static let defaultCompressionQuality: CGFloat = 0.7
    static let minCompressionQuality: CGFloat = 0.1
    static let compressionStep: CGFloat = 0.1
}

// MARK: - Error Messages
enum ErrorMessages {
    static let missingAPIKey = "Please add your OpenAI API Key in Settings to use AI features."
    static let networkUnavailable = "No internet connection detected. Please check your network settings and try again."
    static let transcriptionFailed = "Voice transcription failed. Please check your API key in Settings."
    static let cameraUnavailable = "Camera is not available on this device."
    static let cameraPermissionDenied = "Camera access was previously denied. Please enable it in Settings."
    static let importFailed = "Import failed. Please check the file format."
}

// MARK: - Color Extensions
extension Color {
    static let aiBlue = Color.blue
    static let aiRed = Color.red
    static let aiGreen = Color.green
}
