// ============================================================================
// FamilyUser.swift
// FamilyHub
//
// PURPOSE:
//   Represents an authenticated user within a family group.
//   Stored in Firestore `users/{uid}` — one document per Firebase Auth user.
//
// KEY RESPONSIBILITIES:
//   - Carries identity (name, email, avatar) for display across the app.
//   - Tracks family membership (`familyId`) and role-based permissions (`role`).
//   - Holds the reward wallet balance (`balance`).
//   - Flags onboarding completion (`hasCompletedOnboarding`) to control app routing.
//
// ROLE MODEL:
//   .admin  — Family creator. Full management rights (assign tasks, approve rewards).
//   .adult  — Adult family member who joined via invite. Same rights as admin in practice.
//   .member — Child/minor. Can complete tasks and earn rewards but cannot approve or manage.
//
// AGE LOGIC:
//   `isAdult` and `age` compute from `dateOfBirth` against the current date.
//   `joinFamily()` in FamilyManagementService uses `isAdult` to assign the correct role.
//
// ============================================================================

import Foundation
import FirebaseFirestore

/// An authenticated user and their profile within FamilyHub.
///
/// Synced in real-time to `AuthViewModel.currentUser` via a Firestore snapshot listener.
struct FamilyUser: Identifiable, Codable, Hashable {
    
    /// Firebase Auth UID (also the Firestore document ID).
    /// Nil before first Firestore write; always present for authenticated users.
    @DocumentID var id: String?
    
    /// The user's email address. Set on sign-up, not editable after.
    var email: String
    
    /// Public display name shown in family views, task assignments, and notifications.
    var displayName: String
    
    /// HTTPS URL to the user's profile photo (Firebase Storage or Google avatar URL).
    /// Nil for Apple Sign-In users (Apple doesn't provide profile photos).
    var avatarURL: String?
    
    /// User's date of birth. Used to compute `isAdult` and `age`.
    var dateOfBirth: Date
    
    /// Firestore document ID of the family this user belongs to.
    /// Nil until the user creates or joins a family.
    var familyId: String?
    
    /// Permission level within the family. Determines what actions the user can take.
    var role: UserRole
    
    /// Account creation timestamp.
    var createdAt: Date
    
    /// Current reward wallet balance in dollars.
    /// Updated atomically by `FieldValue.increment()` in TaskViewModel and FamilyManagementService.
    var balance: Double
    
    /// Optional personal goal or motto displayed on the profile card.
    var goal: String?
    
    /// Whether this user has completed the onboarding flow.
    ///
    /// `nil` for accounts created before the onboarding feature shipped (treated as `false`).
    /// Set to `true` by `FamilyManagementService.completeOnboarding()`.
    /// Used by `ContentView` routing to show onboarding on first launch.
    var hasCompletedOnboarding: Bool?
    
    // MARK: - Subscription & Credits
    
    /// Current subscription tier: "free" or "premium". Defaults to "free".
    /// Updated by SubscriptionManager after StoreKit purchase verification.
    var subscription: String?
    
    /// Purchased AI credits balance. 1 credit = 1 AI action.
    /// Used when daily quota is exhausted. Credits never expire.
    var aiCredits: Int?
    
    /// Whether user has an active premium subscription.
    var isPremium: Bool {
        subscription == "premium"
    }
    
    // MARK: - Computed Properties
    
    /// `true` if the user is 18 or older based on `dateOfBirth`.
    ///
    /// Used by `FamilyManagementService.joinFamily()` to assign `.adult` vs `.member` role.
    var isAdult: Bool {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return age >= 18
    }
    
    /// Current age in whole years.
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    // MARK: - Role Enum
    
    enum UserRole: String, Codable, CaseIterable {
        /// Family creator. Full administrative rights.
        case admin = "admin"
        /// Adult member who joined via invite. Same functional rights as admin.
        case adult = "adult"
        /// Child/minor member. Can complete tasks and earn rewards.
        case member = "member"
    }
}
