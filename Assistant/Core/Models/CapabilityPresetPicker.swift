//
//  CapabilityPresetPicker.swift
//  Assistant
//
//  Created by Ramiro  on 3/23/26.
//
// PURPOSE:
//   Reusable view for selecting capability presets and customizing granular
//   permissions on a family member. Used inside MemberDetailView.
//
// LOCALIZATION:
//   All user-facing strings use xcstrings keys as LocalizedStringKey.
//   SwiftUI resolves them automatically via .environment(\.locale).
//   Keys: preset_standard, preset_older_sibling, can_assign_tasks, etc.
//
// ============================================================================

import SwiftUI

// MARK: - Preset Picker

struct CapabilityPresetPicker: View {

    /// The member being configured.
    let member: FamilyUser

    /// All family members (for computing younger siblings).
    let allMembers: [FamilyUser]

    /// Called when the user selects a preset or modifies capabilities.
    let onSave: (MemberCapabilities, CapabilityPreset) -> Void

    // MARK: - State

    @State private var selectedPreset: CapabilityPreset
    @State private var capabilities: MemberCapabilities
    @State private var showCustomize = false

    init(
        member: FamilyUser,
        allMembers: [FamilyUser],
        onSave: @escaping (MemberCapabilities, CapabilityPreset) -> Void
    ) {
        self.member = member
        self.allMembers = allMembers
        self.onSave = onSave
        _selectedPreset = State(initialValue: member.resolvedPreset)
        _capabilities = State(initialValue: member.resolvedCapabilities)
    }

    /// Members younger than the target (for scoped assignment).
    private var youngerMemberIds: [String] {
        allMembers.compactMap { other in
            guard let otherId = other.id, otherId != member.id else { return nil }
            return other.age < member.age ? otherId : nil
        }
    }

    /// Presets shown in the picker grid (exclude "custom").
    private var selectablePresets: [CapabilityPreset] {
        [.standard, .olderSibling, .coParent, .fullAdmin]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {

            // Section header
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.accentPrimary)
                Text("permissions")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textSecondary)
            }

            // Preset grid
            VStack(spacing: DS.Spacing.sm) {
                ForEach(selectablePresets) { preset in
                    presetRow(preset)
                }
            }

            // Customize disclosure
            DisclosureGroup(
                isExpanded: $showCustomize,
                content: {
                    customizeToggles
                        .padding(.top, DS.Spacing.sm)
                },
                label: {
                    Text("customize")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                }
            )
            .tint(.textSecondary)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
        )
    }

    // MARK: - Preset Row

    private func presetRow(_ preset: CapabilityPreset) -> some View {
        let isSelected = selectedPreset == preset

        return Button {
            DS.Haptics.light()
            selectedPreset = preset
            capabilities = preset.capabilities(youngerMemberIds: youngerMemberIds)
            showCustomize = false
            onSave(capabilities, preset)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: preset.icon)
                    .font(DS.Typography.body())
                    .foregroundStyle(isSelected ? .textOnAccent : .accentPrimary)
                    .frame(width: DS.IconContainer.sm, height: DS.IconContainer.sm)
                    .background(
                        Circle().fill(isSelected ? Color.accentPrimary : Color.accentPrimary.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Use LocalizedStringKey via the xcstrings key
                    Text(LocalizedStringKey(preset.localizationKey))
                        .font(DS.Typography.body())
                        .foregroundStyle(isSelected ? .accentPrimary : .textPrimary)
                        .fontWeight(isSelected ? .semibold : .regular)

                    Text(LocalizedStringKey(preset.descriptionKey))
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentPrimary)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.08) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(
                        isSelected ? Color.accentPrimary.opacity(0.3) : Color.themeCardBorder,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Custom Toggles

    private var customizeToggles: some View {
        VStack(spacing: DS.Spacing.md) {
            capabilityToggle("can_assign_tasks", icon: "person.badge.plus", isOn: $capabilities.canAssignTasks)
            capabilityToggle("can_attach_rewards", icon: "dollarsign.circle", isOn: $capabilities.canAttachRewards)
            capabilityToggle("can_approve_payouts", icon: "banknote", isOn: $capabilities.canApprovePayouts)
            capabilityToggle("can_verify_homework", icon: "checkmark.seal", isOn: $capabilities.canVerifyHomework)
            capabilityToggle("can_manage_family", icon: "person.3", isOn: $capabilities.canManageFamily)
        }
        .onChange(of: capabilities) { _, newCaps in
            selectedPreset = .custom
            onSave(newCaps, .custom)
        }
    }

    /// A single capability toggle row.
    /// - Parameter titleKey: An xcstrings key (e.g. `"can_assign_tasks"`).
    ///   Passed as `LocalizedStringKey` so `Text()` auto-resolves from the String Catalog.
    private func capabilityToggle(
        _ titleKey: LocalizedStringKey,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 24)
                Text(titleKey)
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textPrimary)
            }
        }
        .tint(.accentPrimary)
    }
}

// MARK: - Capability Badge

/// Compact badge showing a user's capability preset.
/// Replaces the old `RoleBadge(role:)` in member lists.
struct CapabilityBadge: View {
    let preset: CapabilityPreset

    var body: some View {
        Text(LocalizedStringKey(preset.localizationKey))
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.textOnAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeColor))
    }

    private var badgeColor: Color {
        switch preset {
        case .fullAdmin:    .accentOrange
        case .coParent:     .accentPrimary
        case .olderSibling: .accentTertiary
        case .standard:     .textTertiary
        case .custom:       .accentSecondary
        }
    }
}
