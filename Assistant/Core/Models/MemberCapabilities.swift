// ============================================================================
// MemberCapabilities.swift
//
// PURPOSE:
//   Defines the capability-based permission model that replaces flat role checks.
//   A user's capabilities determine what they can DO, not who they ARE.
//
// DESIGN:
//   - 6 discrete capabilities (booleans + one scoped array)
//   - 4 presets for one-tap configuration + Custom
//   - Fallback resolver: nil capabilities → derive from existing role
//   - Sendable + Codable for Firestore and cross-actor safety
//
// LOCALIZATION:
//   Preset display names use xcstrings keys (e.g. "preset_standard").
//   In SwiftUI views → Text(preset.localizationKey) auto-resolves via env locale.
//   In code context  → preset.displayName uses AppStrings.localized().
//
// ============================================================================

import Foundation

// MARK: - MemberCapabilities

/// Discrete permission flags for a family member.
///
/// Each capability controls a specific action surface in the app.
/// Views check these flags to show/hide UI elements — never disabled states.
struct MemberCapabilities: Codable, Hashable, Sendable, Equatable {

    /// Can create tasks assigned to OTHER family members (not just self).
    var canAssignTasks: Bool

    /// Member IDs this user can assign to.
    /// Empty `[]` = unrestricted. Non-empty = scoped.
    var canAssignTo: [String]

    /// Can attach dollar rewards to tasks.
    var canAttachRewards: Bool

    /// Can approve or reject payout requests.
    var canApprovePayouts: Bool

    /// Can trigger AI homework verification and approve/reject.
    var canVerifyHomework: Bool

    /// Can invite/remove members, edit family name and banner.
    var canManageFamily: Bool

    // MARK: - Convenience

    var isUnrestrictedAssignment: Bool {
        canAssignTasks && canAssignTo.isEmpty
    }

    func canAssign(to memberId: String) -> Bool {
        guard canAssignTasks else { return false }
        return canAssignTo.isEmpty || canAssignTo.contains(memberId)
    }
}

// MARK: - CapabilityPreset

/// One-tap presets covering 90% of family configurations.
enum CapabilityPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard     = "standard"
    case olderSibling = "older_sibling"
    case coParent     = "co_parent"
    case fullAdmin    = "full_admin"
    case custom       = "custom"

    var id: String { rawValue }

    // ── Localization Keys (match Localizable.xcstrings) ──────────

    /// Key for the preset display name in xcstrings.
    /// SwiftUI: `Text(LocalizedStringKey(preset.localizationKey))`
    var localizationKey: String {
        switch self {
        case .standard:     "preset_standard"
        case .olderSibling: "preset_older_sibling"
        case .coParent:     "preset_co_parent"
        case .fullAdmin:    "preset_full_admin"
        case .custom:       "preset_custom"
        }
    }

    /// Key for the preset description in xcstrings.
    var descriptionKey: String {
        switch self {
        case .standard:     "preset_standard_desc"
        case .olderSibling: "preset_older_sibling_desc"
        case .coParent:     "preset_co_parent_desc"
        case .fullAdmin:    "preset_full_admin_desc"
        case .custom:       "preset_custom_desc"
        }
    }

    /// Resolved display name string. Use in code (ViewModels, services).
    /// In SwiftUI body, prefer `Text(LocalizedStringKey(preset.localizationKey))`.
    var displayName: String {
        AppStrings.localized(.init(localizationKey))
    }

    /// Resolved description string.
    var subtitle: String {
        AppStrings.localized(.init(descriptionKey))
    }

    /// SF Symbol icon.
    var icon: String {
        switch self {
        case .standard:     "person.fill"
        case .olderSibling: "person.2.fill"
        case .coParent:     "person.2.circle.fill"
        case .fullAdmin:    "star.circle.fill"
        case .custom:       "slider.horizontal.3"
        }
    }

    // ── Capability Factory ───────────────────────────────────────

    /// The capabilities this preset grants.
    /// - Parameter youngerMemberIds: For `.olderSibling`, scopes `canAssignTo`.
    func capabilities(youngerMemberIds: [String] = []) -> MemberCapabilities {
        switch self {
        case .standard:
            MemberCapabilities(
                canAssignTasks: false, canAssignTo: [],
                canAttachRewards: false, canApprovePayouts: false,
                canVerifyHomework: false, canManageFamily: false
            )
        case .olderSibling:
            MemberCapabilities(
                canAssignTasks: true, canAssignTo: youngerMemberIds,
                canAttachRewards: true, canApprovePayouts: false,
                canVerifyHomework: true, canManageFamily: false
            )
        case .coParent:
            MemberCapabilities(
                canAssignTasks: true, canAssignTo: [],
                canAttachRewards: true, canApprovePayouts: true,
                canVerifyHomework: true, canManageFamily: false
            )
        case .fullAdmin:
            MemberCapabilities(
                canAssignTasks: true, canAssignTo: [],
                canAttachRewards: true, canApprovePayouts: true,
                canVerifyHomework: true, canManageFamily: true
            )
        case .custom:
            CapabilityPreset.fullAdmin.capabilities()
        }
    }

    // ── Reverse Detection ────────────────────────────────────────

    /// Detect which preset matches a capabilities struct.
    /// Returns `.custom` if no exact match.
    static func detect(from caps: MemberCapabilities) -> CapabilityPreset {
        if !caps.canAssignTasks && !caps.canAttachRewards && !caps.canApprovePayouts
            && !caps.canVerifyHomework && !caps.canManageFamily {
            return .standard
        }
        if caps.canAssignTasks && caps.canAttachRewards && !caps.canApprovePayouts
            && caps.canVerifyHomework && !caps.canManageFamily && !caps.canAssignTo.isEmpty {
            return .olderSibling
        }
        if caps.canAssignTasks && caps.canAttachRewards && caps.canApprovePayouts
            && caps.canVerifyHomework && !caps.canManageFamily && caps.canAssignTo.isEmpty {
            return .coParent
        }
        if caps.canAssignTasks && caps.canAttachRewards && caps.canApprovePayouts
            && caps.canVerifyHomework && caps.canManageFamily && caps.canAssignTo.isEmpty {
            return .fullAdmin
        }
        return .custom
    }
}

// MARK: - FamilyUser Fallback Resolution

extension FamilyUser {

    /// Effective capabilities: explicit if set, otherwise derived from legacy role.
    var resolvedCapabilities: MemberCapabilities {
        if let caps = capabilities { return caps }
        switch role {
        case .admin, .adult: return CapabilityPreset.fullAdmin.capabilities()
        case .member:        return CapabilityPreset.standard.capabilities()
        }
    }

    /// Detected preset for the current capabilities.
    var resolvedPreset: CapabilityPreset {
        if let raw = capabilityPreset, let p = CapabilityPreset(rawValue: raw) {
            return p
        }
        return CapabilityPreset.detect(from: resolvedCapabilities)
    }
}
