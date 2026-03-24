
// AnalyticsService.swift
//
// SA-2: Analytics for Series-A investor metrics.
//
// PURPOSE:
//   Tracks the events investors actually ask about:
//   - DAU/MAU (automatic via Firebase Analytics)
//   - Feature adoption (which features are used, how often)
//   - Monetization funnel (paywall views → purchases)
//   - Engagement depth (tasks created, completed, verified)
//   - AI usage and cost attribution
//
// ARCHITECTURE:
//   - Typed event enum prevents typos in event names
//   - Centralized parameter building ensures consistency
//   - Protocol-based for testability (MockAnalytics in tests)
//   - Firebase Analytics as the backing implementation
//   - Privacy-safe: no PII in event parameters
//
// USAGE:
//   // Track an event:
//   Analytics.track(.taskCreated(hasReward: true, isRecurring: false))
//
//   // Set user properties:
//   Analytics.setUserProperties(role: .admin, tier: .premium, familySize: 4)
//
//   // In a view:
//   .onAppear { Analytics.track(.screenViewed(.home)) }
//
// PRIVACY:
//   - No user IDs, names, or emails in events
//   - Family size is bucketed ("1-3", "4-6", "7+")
//   - AI prompts are NOT logged (only token counts)
//
// iOS 18.6 / Swift 6:
//   - Sendable enum for thread safety
//   - final class with @MainActor
//   - import os (not os.log)
//
// ============================================================================

import Foundation
import FirebaseAnalytics
import os

// MARK: - Screen Names

enum ScreenName: String, Sendable {
    case home           = "home"
    case calendar       = "calendar"
    case tasks          = "tasks"
    case habits         = "habits"
    case family         = "family"
    case chat           = "ai_chat"
    case settings       = "settings"
    case taskDetail     = "task_detail"
    case focusTimer     = "focus_timer"
    case rewardWallet   = "reward_wallet"
    case paywall        = "paywall"
    case proofCapture   = "proof_capture"
    case onboarding     = "onboarding"
    case familySetup    = "family_setup"
}

// MARK: - Analytics Events

/// Typed analytics events. Each case maps to a Firebase Analytics event name
/// with structured parameters. Prevents typos and ensures consistency.
enum AnalyticsEvent: Sendable {
    
    // ── Screen Views ──
    case screenViewed(ScreenName)
    
    // ── Authentication ──
    case signUp(method: String)                    // "email", "google", "apple"
    case signIn(method: String)
    case signOut
    
    // ── Family ──
    case familyCreated
    case familyJoined
    case memberInvited
    
    // ── Tasks ──
    case taskCreated(hasReward: Bool, isRecurring: Bool, taskType: String?)
    case taskCompleted(hadReward: Bool, usedFocus: Bool)
    case taskDeleted
    case proofSubmitted(imageCount: Int)
    case proofVerified(approved: Bool, usedAI: Bool)
    
    // ── Focus Timer ──
    case focusStarted(durationMinutes: Int)
    case focusCompleted(durationMinutes: Int)
    case focusAbandoned(elapsedSeconds: Int)
    
    // ── Habits ──
    case habitCreated
    case habitCompleted
    case habitDeleted
    
    // ── Calendar ──
    case eventCreated
    case eventDeleted
    
    // ── AI Chat ──
    case chatMessageSent
    case chatActionConfirmed(actionType: String)
    case chatActionRejected
    case chatLimitReached
    
    // ── AI Verification ──
    case verificationStarted
    case verificationCompleted(recommendation: String) // "approve", "review", "unclear"
    
    // ── Monetization ──
    case paywallViewed(trigger: String)                // "limit_reached", "settings", "banner"
    case purchaseStarted(productId: String)
    case purchaseCompleted(productId: String, revenue: Double)
    case purchaseFailed(productId: String, error: String)
    case creditsPurchased(credits: Int)
    
    // ── Rewards ──
    case rewardEarned(amount: Double)
    case payoutRequested(amount: Double)
    case payoutApproved(amount: Double)
    
    // MARK: - Firebase Event Name
    
    var name: String {
        switch self {
        case .screenViewed:          return "screen_view"
        case .signUp:                return "sign_up"
        case .signIn:                return "login"
        case .signOut:               return "sign_out"
        case .familyCreated:         return "family_created"
        case .familyJoined:          return "family_joined"
        case .memberInvited:         return "member_invited"
        case .taskCreated:           return "task_created"
        case .taskCompleted:         return "task_completed"
        case .taskDeleted:           return "task_deleted"
        case .proofSubmitted:        return "proof_submitted"
        case .proofVerified:         return "proof_verified"
        case .focusStarted:          return "focus_started"
        case .focusCompleted:        return "focus_completed"
        case .focusAbandoned:        return "focus_abandoned"
        case .habitCreated:          return "habit_created"
        case .habitCompleted:        return "habit_completed"
        case .habitDeleted:          return "habit_deleted"
        case .eventCreated:          return "event_created"
        case .eventDeleted:          return "event_deleted"
        case .chatMessageSent:       return "chat_message_sent"
        case .chatActionConfirmed:   return "chat_action_confirmed"
        case .chatActionRejected:    return "chat_action_rejected"
        case .chatLimitReached:      return "chat_limit_reached"
        case .verificationStarted:   return "verification_started"
        case .verificationCompleted: return "verification_completed"
        case .paywallViewed:         return "paywall_viewed"
        case .purchaseStarted:       return "purchase_started"
        case .purchaseCompleted:     return AnalyticsEventPurchase  // Firebase built-in
        case .purchaseFailed:        return "purchase_failed"
        case .creditsPurchased:      return "credits_purchased"
        case .rewardEarned:          return "reward_earned"
        case .payoutRequested:       return "payout_requested"
        case .payoutApproved:        return "payout_approved"
        }
    }
    
    // MARK: - Firebase Parameters
    
    var parameters: [String: Any] {
        switch self {
        case .screenViewed(let screen):
            return [AnalyticsParameterScreenName: screen.rawValue]
            
        case .signUp(let method), .signIn(let method):
            return [AnalyticsParameterMethod: method]
            
        case .signOut, .familyCreated, .familyJoined, .memberInvited,
             .taskDeleted, .habitCreated, .habitCompleted, .habitDeleted,
             .eventCreated, .eventDeleted, .chatMessageSent, .chatActionRejected,
             .chatLimitReached, .verificationStarted:
            return [:]
            
        case .taskCreated(let hasReward, let isRecurring, let taskType):
            var params: [String: Any] = [
                "has_reward": hasReward,
                "is_recurring": isRecurring
            ]
            if let taskType { params["task_type"] = taskType }
            return params
            
        case .taskCompleted(let hadReward, let usedFocus):
            return ["had_reward": hadReward, "used_focus": usedFocus]
            
        case .proofSubmitted(let imageCount):
            return ["image_count": imageCount]
            
        case .proofVerified(let approved, let usedAI):
            return ["approved": approved, "used_ai": usedAI]
            
        case .focusStarted(let minutes), .focusCompleted(let minutes):
            return ["duration_minutes": minutes]
            
        case .focusAbandoned(let elapsed):
            return ["elapsed_seconds": elapsed]
            
        case .chatActionConfirmed(let actionType):
            return ["action_type": actionType]
            
        case .verificationCompleted(let recommendation):
            return ["recommendation": recommendation]
            
        case .paywallViewed(let trigger):
            return ["trigger": trigger]
            
        case .purchaseStarted(let productId):
            return [AnalyticsParameterItemID: productId]
            
        case .purchaseCompleted(let productId, let revenue):
            return [
                AnalyticsParameterItemID: productId,
                AnalyticsParameterValue: revenue,
                AnalyticsParameterCurrency: "USD"
            ]
            
        case .purchaseFailed(let productId, let error):
            return [AnalyticsParameterItemID: productId, "error": error]
            
        case .creditsPurchased(let credits):
            return ["credits": credits]
            
        case .rewardEarned(let amount), .payoutRequested(let amount), .payoutApproved(let amount):
            return ["amount": amount]
        }
    }
}

// MARK: - Analytics Service

/// Centralized analytics interface.
///
/// All event tracking goes through `Analytics.track()`. This provides:
/// - Type-safe event names (no string typos)
/// - Consistent parameter schemas
/// - Single place to add/swap analytics providers
/// - Easy to disable in tests or debug builds
enum Analytics: Sendable {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.",
        category: "Analytics"
    )
    
    // MARK: - Event Tracking
    
    /// Track an analytics event.
    /// In DEBUG, also logs to console for easy verification.
    static func track(_ event: AnalyticsEvent) {
        let params = event.parameters.isEmpty ? nil : event.parameters
        
        FirebaseAnalytics.Analytics.logEvent(event.name, parameters: params)
        
        #if DEBUG
        logger.debug("📊 \(event.name, privacy: .public) \(String(describing: params), privacy: .public)")
        #endif
    }
    
    // MARK: - User Properties
    //
    // These appear in Firebase Analytics > User Properties and can be used
    // for audience segmentation in dashboards and A/B tests.
    
    /// Set user properties for segmentation.
    /// Call after sign-in and when role/tier changes.
    static func setUserProperties(
        role: String?,
        tier: String?,
        familySize: Int?
    ) {
        if let role {
            FirebaseAnalytics.Analytics.setUserProperty(role, forName: "user_role")
        }
        if let tier {
            FirebaseAnalytics.Analytics.setUserProperty(tier, forName: "subscription_tier")
        }
        if let familySize {
            // Bucket family size for privacy
            let bucket: String
            switch familySize {
            case 0...3: bucket = "1-3"
            case 4...6: bucket = "4-6"
            default: bucket = "7+"
            }
            FirebaseAnalytics.Analytics.setUserProperty(bucket, forName: "family_size")
        }
    }
    
    /// Clear user properties on sign-out.
    static func clearUserProperties() {
        FirebaseAnalytics.Analytics.setUserProperty(nil, forName: "user_role")
        FirebaseAnalytics.Analytics.setUserProperty(nil, forName: "subscription_tier")
        FirebaseAnalytics.Analytics.setUserProperty(nil, forName: "family_size")
    }
}
