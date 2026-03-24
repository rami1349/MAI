// ============================================================================
// AppLogger.swift
// 
//
// PURPOSE:
//   Centralized structured logging using Apple's os.Logger framework.
//   Replaces all raw print() calls with categorized, level-aware logging
//   that is automatically stripped from Release builds for sensitive data.
//
// CRITICAL FIX (C-2):
//   Raw print() statements in production builds:
//   - Write to os_log on every Firestore snapshot (I/O overhead at 100K users)
//   - Leak internal data structures to device console (security risk)
//   - Are a red flag in App Store review and security audits
//
// USAGE:
//   Log.tasks.debug("Loaded \(tasks.count) tasks")
//   Log.auth.info("User signed in: \(userId, privacy: .private)")
//   Log.rewards.error("Transaction failed: \(error)")
//   Log.stream.trace("Content delta received")
//
// PRIVACY:
//   - Use .private for user IDs, emails, task titles (redacted in Release)
//   - Use .public for counts, status codes, feature flags (always visible)
//   - Default is .private (safe by default)
//
// LEVELS:
//   .trace   — Verbose streaming/listener events (stripped in Release)
//   .debug   — Development diagnostics (stripped in Release)
//   .info    — Notable events (visible in Release, not persisted)
//   .error   — Failures requiring attention (persisted to disk)
//   .fault   — Critical failures (persisted + crash-adjacent)
//
// ============================================================================

import os
import Foundation

// MARK: - App Logger Namespace

/// Structured logger categories for .
///
/// Each category maps to a subsystem+category pair in Apple's unified logging
/// system. Logs are viewable in Console.app filtered by subsystem.
///
/// In Release builds:
/// - `.debug` and `.trace` messages are completely stripped by the compiler
/// - `.private` interpolation arguments are redacted to `<private>`
/// - `.info` messages are visible but not persisted to disk
/// - `.error` and `.fault` are persisted and survive device reboots
enum Log {
    
    /// Bundle identifier used as the logging subsystem.
    /// Matches the app's CFBundleIdentifier for Console.app filtering.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "ios.Assistant"
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: Domain Loggers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    /// Authentication, sign-in, sign-out, session management
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    
    /// Task CRUD, status transitions, proof submission
    static let tasks = Logger(subsystem: subsystem, category: "Tasks")
    
    /// Reward payments, balance updates, withdrawal lifecycle
    static let rewards = Logger(subsystem: subsystem, category: "Rewards")
    
    /// Calendar events, EventKit integration
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")
    
    /// Habit tracking, completion logs
    static let habits = Logger(subsystem: subsystem, category: "Habits")
    
    /// In-app and push notification delivery
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    
    /// AI chat, streaming, confirmation flow
    static let chat = Logger(subsystem: subsystem, category: "Chat")
    
    /// SSE streaming service
    static let stream = Logger(subsystem: subsystem, category: "Stream")
    
    /// Firestore decoding, data layer
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    /// Family management, member profiles
    static let family = Logger(subsystem: subsystem, category: "Family")
    
    /// StoreKit, subscriptions, purchases
    static let store = Logger(subsystem: subsystem, category: "Store")
    
    /// Image preprocessing, proof capture
    static let media = Logger(subsystem: subsystem, category: "Media")
    
    /// Account deletion, cleanup
    static let account = Logger(subsystem: subsystem, category: "Account")
    
    /// Homework verification (AI vision)
    static let verification = Logger(subsystem: subsystem, category: "Verification")
    
    /// General app lifecycle, uncategorized
    static let general = Logger(subsystem: subsystem, category: "General")
}

// MARK: - Performance Profiling (OSSignposter — iOS 16+)

extension Log {
    /// Modern signposter for Instruments profiling.
    ///
    /// Usage:
    /// ```swift
    /// let state = Log.signposter.beginInterval("LoadTasks")
    /// // ... async work ...
    /// Log.signposter.endInterval("LoadTasks", state)
    /// ```
    ///
    /// Or with automatic scoping:
    /// ```swift
    /// try await Log.signposter.withIntervalSignpost("LoadTasks") {
    ///     await loadTasks()
    /// }
    /// ```
    static let signposter = OSSignposter(logger: tasks)
}
