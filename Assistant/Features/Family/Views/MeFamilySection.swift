// ============================================================================
// MeFamilySection.swift
//
// ME TAB section 7: My Family
//
// Inline member list with avatars. Previously hidden behind a button
// to FamilyMembersListView. Now visible in the scroll.
//
// - Tap member → MemberDetailView sheet (with heatmap, stats, permissions)
// - "Invite Member" button gated by canManageFamily
//
// ============================================================================

import SwiftUI

struct MeFamilySection: View {
    let members: [FamilyUser]
    let canManageFamily: Bool
    let onSelectMember: (FamilyUser) -> Void
    let onInvite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.accentPrimary.opacity(0.1))
                    )

                Text("my_family")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Text("\(members.count)")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.accentPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accentPrimary.opacity(0.1))
                    )

                Spacer()
            }

            // Member rows
            VStack(spacing: DS.Spacing.xs) {
                ForEach(members, id: \.id) { member in
                    memberRow(member)
                }
            }

            // Invite button (capability-gated)
            if canManageFamily {
                Button(action: onInvite) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "person.badge.plus")
                            .font(DS.Typography.body())
                        Text("invite_family_member")
                            .font(DS.Typography.label())
                    }
                    .foregroundStyle(.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(Color.accentPrimary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
        .tourTarget("me.myFamily")
    }

    // MARK: - Member Row

    private func memberRow(_ member: FamilyUser) -> some View {
        Button(action: { onSelectMember(member) }) {
            HStack(spacing: DS.Spacing.md) {
                AvatarView(user: member, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)

                    CapabilityBadge(preset: member.resolvedPreset)
                }

                Spacer()

                // Balance
                Text(member.balance.currencyString)
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.accentGreen)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeSurfacePrimary)
            )
        }
        .buttonStyle(.plain)
    }
}
