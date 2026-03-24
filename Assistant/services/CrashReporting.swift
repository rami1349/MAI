//
//  CrashReporting.swift
//  Assistant
//
//  Created by Ramiro  on 3/18/26.
//
// SA-2: Crash reporting for Series-A production readiness.
//
// PURPOSE:
//   Investors ask "what's your crash-free rate?" Without Crashlytics,
//   you find out about crashes from App Store reviews — too late.
//
// ARCHITECTURE:
//   Thin wrapper around Firebase Crashlytics that:
//   - Sets structured user context (role, tier, family size)
//   - Records non-fatal errors with categorized keys
//   - Provides breadcrumb logging for crash investigation
//   - Integrates with AppLogger for unified error tracking
//
// SETUP:
//   1. Add FirebaseCrashlytics to your Podfile/SPM
//   2. Add GoogleService-Info.plist run script for dSYM upload
//   3. Call CrashReporting.configure() in AppDelegate
//   4. Call CrashReporting.setUser() after sign-in
//
// USAGE:
//   // Record a non-fatal error:
//   CrashReporting.record(error, context: "TaskViewModel.verifyProof")
//
//   // Leave breadcrumbs for crash investigation:
//   CrashReporting.log("User opened task detail for task \(taskId)")
//
//   // Set custom keys for filtering in dashboard:
//   CrashReporting.setKey("active_listeners", value: 5)
//
// iOS 18.6 / Swift 6:
//   - Sendable-safe API
//   - import os (not os.log)
//
// ============================================================================

import Foundation
import FirebaseCrashlytics
import os

// MARK: - Crash Reporting

enum CrashReporting: Sendable {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.",
        category: "CrashReporting"
    )
    
    // MARK: - Configuration
    
    /// Call once at app launch (in AppDelegate.didFinishLaunchingWithOptions).
    /// Enables Crashlytics collection and sets default keys.
    static func configure() {
        let crashlytics = Crashlytics.crashlytics()
        
        // Enable collection (can be disabled for opt-out users)
        crashlytics.setCrashlyticsCollectionEnabled(true)
        
        // Set app version metadata
        crashlytics.setCustomValue(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            forKey: "app_version"
        )
        crashlytics.setCustomValue(
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            forKey: "build_number"
        )
    }
    
    // MARK: - User Context
    
    /// Set user context for crash reports. Call after sign-in.
    ///
    /// - Important: Only the user ID is set as the Crashlytics user ID.
    ///   Role and tier are set as custom keys (not PII).
    ///   Display names and emails are NEVER sent to Crashlytics.
    static func setUser(
        id: String,
        role: String?,
        tier: String?,
        familySize: Int?
    ) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setUserID(id)
        
        if let role {
            crashlytics.setCustomValue(role, forKey: "user_role")
        }
        if let tier {
            crashlytics.setCustomValue(tier, forKey: "subscription_tier")
        }
        if let familySize {
            crashlytics.setCustomValue(familySize, forKey: "family_size")
        }
    }
    
    /// Clear user context on sign-out.
    static func clearUser() {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setUserID("")
        crashlytics.setCustomValue("", forKey: "user_role")
        crashlytics.setCustomValue("", forKey: "subscription_tier")
    }
    
    // MARK: - Non-Fatal Error Recording
    
    /// Record a non-fatal error with context.
    ///
    /// Use for errors that don't crash the app but indicate problems:
    /// - Firestore decode failures
    /// - Cloud Function call failures
    /// - StoreKit transaction failures
    /// - AI service errors
    ///
    /// - Parameters:
    ///   - error: The error to record.
    ///   - context: A short description of where the error occurred
    ///     (e.g., "TaskViewModel.verifyProof", "ChatVM.sendMessage").
    static func record(_ error: Error, context: String) {
        let crashlytics = Crashlytics.crashlytics()
        
        // Set context as a custom key so it appears in the Crashlytics dashboard
        crashlytics.setCustomValue(context, forKey: "error_context")
        crashlytics.record(error: error)
        
        logger.error("Non-fatal recorded [\(context, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
    }
    
    /// Record a non-fatal with a custom message (when you don't have an Error object).
    static func record(message: String, context: String) {
        let error = NSError(
            domain: "com.",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        record(error, context: context)
    }
    
    // MARK: - Breadcrumb Logging
    
    /// Leave a breadcrumb for crash investigation.
    ///
    /// Breadcrumbs appear in Crashlytics crash reports in chronological order,
    /// helping you reconstruct what the user did before a crash.
    /// Maximum ~64KB of log data is retained per session.
    ///
    /// - Parameter message: Short, privacy-safe description of the action.
    ///   Do NOT include user names, emails, or task titles.
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    
    // MARK: - Custom Keys
    
    /// Set a custom key-value pair for crash report filtering.
    ///
    /// Useful for filtering crash reports in the Firebase Console:
    /// - "active_tab": "home" / "calendar" / "tasks"
    /// - "active_listeners": 5
    /// - "task_count": 142
    /// - "is_offline": true
    static func setKey(_ key: String, value: Any) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
