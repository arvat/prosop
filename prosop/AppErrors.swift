//
//  AppErrors.swift
//  Prosop
//
//  Created by Arvat Vladimir on 15.03.2026.
//

import Foundation

// MARK: - AI Errors
enum AIError: LocalizedError {
    case missingAPIKey
    case networkUnavailable(String)
    case transcriptionFailed(Error)
    case processingFailed(Error)
    case invalidResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return ErrorMessages.missingAPIKey
        case .networkUnavailable(let message):
            return message
        case .transcriptionFailed(let error):
            return "\(ErrorMessages.transcriptionFailed)\n\nError: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "AI request failed. Please check your API key.\n\nError: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service. Please try again."
        case .unauthorized:
            return "Invalid API key. Please check your settings."
        }
    }
}

// MARK: - Validation Errors
enum ValidationError: LocalizedError {
    case missingAPIKey
    case networkUnavailable
    case termsNotAccepted
    case featureNotUnlocked
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return ErrorMessages.missingAPIKey
        case .networkUnavailable:
            return ErrorMessages.networkUnavailable
        case .termsNotAccepted:
            return "Please accept the AI Terms & Conditions to use AI features."
        case .featureNotUnlocked:
            return "This feature requires a premium subscription."
        }
    }
}

// MARK: - Database Errors
enum DatabaseError: LocalizedError {
    case connectionFailed
    case queryFailed(String)
    case saveFailed
    case deleteFailed
    case migrationFailed(version: Int32)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .queryFailed(let query):
            return "Database query failed: \(query)"
        case .saveFailed:
            return "Failed to save data to database"
        case .deleteFailed:
            return "Failed to delete data from database"
        case .migrationFailed(let version):
            return "Database migration to version \(version) failed"
        }
    }
}

// MARK: - Camera Errors
enum CameraError: LocalizedError {
    case unavailable
    case permissionDenied
    case permissionRestricted
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return ErrorMessages.cameraUnavailable
        case .permissionDenied:
            return ErrorMessages.cameraPermissionDenied
        case .permissionRestricted:
            return "Camera access is restricted by parental controls or device management."
        case .captureFailed:
            return "Failed to capture photo. Please try again."
        }
    }
}

// MARK: - Import/Export Errors
enum ImportExportError: LocalizedError {
    case invalidFileFormat
    case readFailed
    case writeFailed
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileFormat:
            return "Invalid file format. Please use a valid CSV file."
        case .readFailed:
            return "Failed to read file. Please check file permissions."
        case .writeFailed:
            return "Failed to write file. Please check available storage."
        case .parseError(let details):
            return "Failed to parse file: \(details)"
        }
    }
}
