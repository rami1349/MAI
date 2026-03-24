// ============================================================================
// FeatureFlagService.swift
// 
//
// SA-3: Feature flag system for Series-A operational readiness.
//
// PURPOSE:
//   Enables kill switches, gradual rollouts, and A/B testing without
//   App Store releases. Investors will ask "can you turn off AI if costs spike?"
//   — this is the answer.
//
// ARCHITECTURE:
//   - Local defaults baked into the binary (app works offline)
//   - Firebase Remote Config overlay (updates without release)
//   - @Observable for reactive SwiftUI integration
//   - Protocol-based for testability
//
// USAGE:
//   // Check a flag anywhere:
//   if FeatureFlagService.shared.isEnabled(.aiChat) { ... }
//
//   // In SwiftUI views:
//   @Environment(FeatureFlagService.self) var flags
//   if flags.isEnabled(.aiStreaming) { streamingView }
//
//   // With remote override:
//   // Set "ff_ai_chat" = false in Firebase Remote Config console
//   // → AI chat disabled for all users within 12 hours (or on next launch)
//
// FLAGS:
//   See FeatureFlag enum below. Each flag has:
//   - A string key matching the Remote Config parameter name
//   - A local default (used when Remote Config hasn't fetched yet)
//
// REMOTE CONFIG KEYS:
//   Parameter names in Firebase Console use "ff_" prefix:
//   ff_ai_chat, ff_ai_streaming, ff_ai_verification, ff_homework_verification,
//   ff_credits_purchase, ff_focus_timer, ff_reward_system, ff_family_invite
//
// iOS 18.6 / Swift 6:
//   - final class for Sendable conformance
//   - @MainActor isolation
//   - import os (not os.log)
//   - Task.sleep(for:) (not nanoseconds:)
//
// ============================================================================

import SwiftUI
import FirebaseRemoteConfig
import os

// MARK: - Feature Flag Definitions

/// All feature flags in the app.
///
/// Each case maps to a Remote Config parameter key ("ff_" + rawValue).
/// Local defaults are defined in `localDefault` — the app works fully
/// offline using these values until Remote Config fetches succeed.
enum FeatureFlag: String, CaseIterable, Sendable {
    
    // ── AI Features (most expensive — need kill switches) ──
    case aiChat              = "ai_chat"
    case aiStreaming          = "ai_streaming"
    case aiVerification       = "ai_verification"
    case homeworkVerification = "homework_verification"
    
    // ── Monetization ──
    case creditsPurchase     = "credits_purchase"
    case premiumPaywall      = "premium_paywall"
    
    // ── Core Features ──
    case focusTimer          = "focus_timer"
    case rewardSystem        = "reward_system"
    case familyInvite        = "family_invite"
    case habitTracking       = "habit_tracking"
    
    // ── Experimental / Rollout ──
    case newHomeLayout       = "new_home_layout"
    case proofDocumentUpload = "proof_document_upload"
    
    /// Remote Config parameter key
    var remoteKey: String { "ff_\(rawValue)" }
    
    /// Default value baked into the binary.
    /// Used when Remote Config hasn't fetched yet or has no override.
    var localDefault: Bool {
        switch self {
        // AI features default ON (can be killed remotely)
        case .aiChat, .aiStreaming, .aiVerification, .homeworkVerification:
            return true
            
        // Monetization defaults ON
        case .creditsPurchase, .premiumPaywall:
            return true
            
        // Core features default ON
        case .focusTimer, .rewardSystem, .familyInvite, .habitTracking:
            return true
            
        // Experimental features default OFF (opt-in via Remote Config)
        case .newHomeLayout, .proofDocumentUpload:
            return false
        }
    }
}

// MARK: - Feature Flag Service

/// Manages feature flags with local defaults + Firebase Remote Config overlay.
///
/// On launch, local defaults are used immediately (no blocking network call).
/// Remote Config is fetched in the background and applied on next access.
/// Fetch interval: 12 hours in production, 0 in DEBUG.
@MainActor
@Observable
final class FeatureFlagService {
    
    static let shared = FeatureFlagService()
    
    // MARK: - State
    
    /// Resolved flag values (local defaults merged with remote overrides)
    private(set) var flags: [FeatureFlag: Bool] = [:]
    
    /// Whether Remote Config has been fetched at least once this session
    private(set) var hasFetchedRemote = false
    
    /// Last fetch error (for debug UI)
    private(set) var lastFetchError: String?
    
    // MARK: - Private
    
    @ObservationIgnored private let remoteConfig = RemoteConfig.remoteConfig()
    @ObservationIgnored private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.", category: "FeatureFlags")
    
    // MARK: - Init
    
    private init() {
        // Set local defaults immediately (no network required)
        var defaults: [String: NSObject] = [:]
        for flag in FeatureFlag.allCases {
            defaults[flag.remoteKey] = NSNumber(value: flag.localDefault)
            flags[flag] = flag.localDefault
        }
        remoteConfig.setDefaults(defaults)
        
        // Configure fetch interval
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0  // Always fetch in debug
        #else
        settings.minimumFetchInterval = 12 * 60 * 60  // 12 hours in production
        #endif
        remoteConfig.configSettings = settings
    }
    
    // MARK: - Public API
    
    /// Check if a feature flag is enabled.
    /// Returns the local default if Remote Config hasn't fetched yet.
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        flags[flag] ?? flag.localDefault
    }
    
    /// Fetch latest flag values from Firebase Remote Config.
    /// Call this on app launch (non-blocking) and periodically.
    func fetchFlags() async {
        do {
            let status = try await remoteConfig.fetch()
            
            guard status == .success else {
                Self.logger.debug("Remote Config fetch returned status: \(String(describing: status), privacy: .public)")
                return
            }
            
            // Activate fetched values
            try await remoteConfig.activate()
            
            // Update local flags from remote values
            for flag in FeatureFlag.allCases {
                let value = remoteConfig.configValue(forKey: flag.remoteKey).boolValue
                flags[flag] = value
            }
            
            hasFetchedRemote = true
            lastFetchError = nil
            
            Self.logger.info("Feature flags updated from Remote Config (\(FeatureFlag.allCases.count, privacy: .public) flags)")
            
        } catch {
            lastFetchError = error.localizedDescription
            Self.logger.error("Remote Config fetch failed: \(error.localizedDescription, privacy: .public)")
            // Local defaults remain in effect — app continues working
        }
    }
    
    /// Force-override a flag locally (for testing / debug).
    /// Does NOT persist to Remote Config — resets on next fetch.
    #if DEBUG
    func override(_ flag: FeatureFlag, enabled: Bool) {
        flags[flag] = enabled
        Self.logger.debug("Flag overridden: \(flag.rawValue, privacy: .public) = \(enabled, privacy: .public)")
    }
    
    /// Reset all local overrides back to Remote Config / defaults.
    func resetOverrides() {
        for flag in FeatureFlag.allCases {
            flags[flag] = remoteConfig.configValue(forKey: flag.remoteKey).boolValue
        }
        Self.logger.debug("All flag overrides reset")
    }
    #endif
}

// MARK: - SwiftUI Environment Integration

/// Add to DependencyContainer or inject directly via .environment()
///
/// Usage in AssistantApp.swift:
///   .environment(FeatureFlagService.shared)
///   .task { await FeatureFlagService.shared.fetchFlags() }
///
/// Usage in views:
///   @Environment(FeatureFlagService.self) var flags
///   if flags.isEnabled(.aiChat) { AIChatView() }

// MARK: - Convenience Extensions

extension View {
    /// Conditionally shows content based on a feature flag.
    ///
    /// Usage:
    ///   Text("New Feature").featureGated(.newHomeLayout)
    @ViewBuilder
    func featureGated(_ flag: FeatureFlag) -> some View {
        if FeatureFlagService.shared.isEnabled(flag) {
            self
        }
    }
}
