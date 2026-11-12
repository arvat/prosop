//
//  ReviewManager.swift
//  prosop
//
//  Created by Arvat Vladimir on 13.02.2026.
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Review Manager
@MainActor
final class ReviewManager {
    static let shared = ReviewManager()
    
    // UserDefaults keys
    private let firstLaunchDateKey = "firstLaunchDate"
    private let appLaunchCountKey = "appLaunchCount"
    private let lastReviewRequestDateKey = "lastReviewRequestDate"
    private let hasRequestedReviewKey = "hasRequestedReview"
    
    // Configuration
    private let daysBeforeReview = 2.0 // Days to wait before showing review
    private let minimumLaunchCount = 5 // Minimum number of app launches
    private let daysBetweenReviewPrompts = 90.0 // Wait 90 days before asking again
    
    private init() {
        // Track first launch
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }
        
        // Increment launch count
        incrementLaunchCount()
    }
    
    // MARK: - Launch Tracking
    private func incrementLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: appLaunchCountKey)
    }
    
    // MARK: - Check if Should Request Review
    func checkAndRequestReview() {
        guard shouldRequestReview() else { return }
        
        // Request review
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            
            // Update last request date
            UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
            UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)
            
            print("📝 Review prompt shown")
        }
    }
    
    // MARK: - Determine if Review Should Be Requested
    private func shouldRequestReview() -> Bool {
        // Get first launch date
        guard let firstLaunchDate = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date else {
            return false
        }
        
        // Check if enough days have passed since first launch
        let daysSinceFirstLaunch = Date().timeIntervalSince(firstLaunchDate) / 86400
        guard daysSinceFirstLaunch >= daysBeforeReview else {
            print("📝 Review check: Not enough days since first launch (\(String(format: "%.1f", daysSinceFirstLaunch))/\(daysBeforeReview) days)")
            return false
        }
        
        // Check if enough launches have occurred
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        guard launchCount >= minimumLaunchCount else {
            print("📝 Review check: Not enough launches (\(launchCount)/\(minimumLaunchCount))")
            return false
        }
        
        // Check if we've already requested a review recently
        if let lastReviewRequestDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date {
            let daysSinceLastRequest = Date().timeIntervalSince(lastReviewRequestDate) / 86400
            guard daysSinceLastRequest >= daysBetweenReviewPrompts else {
                print("📝 Review check: Too soon since last request (\(String(format: "%.1f", daysSinceLastRequest))/\(daysBetweenReviewPrompts) days)")
                return false
            }
        }
        
        print("✅ Review check passed: \(String(format: "%.1f", daysSinceFirstLaunch)) days, \(launchCount) launches")
        return true
    }
    
    // MARK: - Manual Trigger (for Testing)
    func requestReviewManually() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
            print("📝 Manual review prompt triggered")
        }
    }
    
    // MARK: - Reset for Testing
    #if DEBUG
    func resetReviewTracking() {
        UserDefaults.standard.removeObject(forKey: firstLaunchDateKey)
        UserDefaults.standard.removeObject(forKey: appLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: lastReviewRequestDateKey)
        UserDefaults.standard.removeObject(forKey: hasRequestedReviewKey)
        print("🔄 Review tracking reset")
    }
    
    func printReviewStatus() {
        let firstLaunchDate = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        let lastReviewDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date
        
        print("""
        📝 Review Status:
        - First Launch: \(firstLaunchDate?.formatted() ?? "Never")
        - Launch Count: \(launchCount)
        - Last Review Request: \(lastReviewDate?.formatted() ?? "Never")
        - Should Request Now: \(shouldRequestReview())
        """)
    }
    #endif
}
