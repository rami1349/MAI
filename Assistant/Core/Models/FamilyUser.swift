// ============================================================================
// FamilyUser.swift
//
// PURPOSE:
//   Represents an authenticated user within a family group.
//   Stored in Firestore `users/{uid}`.
//
// PERMISSION MODEL (v2 — Capabilities, Not Roles):
//   `capabilities` (MemberCapabilities?) controls what this user can do.
//   When nil, falls back to legacy `role` via `resolvedCapabilities`.
//   Views and backend check capabilities, never roles directly.
//
// ============================================================================

import Foundation
import FirebaseFirestore

struct FamilyUser: Identifiable, Codable, Hashable, Sendable {

    @DocumentID var id: String?

    var email: String
    var displayName: String
    var avatarURL: String?
    var dateOfBirth: Date
    var familyId: String?

    /// Legacy permission level. Kept for backward compatibility.
    /// New code should use `resolvedCapabilities` instead.
    var role: UserRole

    var createdAt: Date
    var balance: Double
    var goal: String?
    var hasCompletedOnboarding: Bool?

    // MARK: - Subscription & Credits

    var subscription: String?
    var aiCredits: Int?

    var isPremium: Bool { subscription == "premium" }

    // MARK: - Capabilities (v2)

    /// Explicit capability flags set by a parent/admin.
    /// When `nil`, capabilities are derived from `role` via `resolvedCapabilities`.
    var capabilities: MemberCapabilities?

    /// Which preset was last applied: "standard", "older_sibling", "co_parent",
    /// "full_admin", "custom". Used by UI to highlight active selection.
    var capabilityPreset: String?

    // MARK: - Computed

    var isAdult: Bool {
        let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 0
        return years >= 18
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 0
    }

    // MARK: - Legacy Role Enum

    enum UserRole: String, Codable, CaseIterable, Sendable {
        case admin  = "admin"
        case adult  = "adult"
        case member = "member"
    }
}
