// ============================================================================
// MeProfileSection.swift
//
// ME TAB sections: Family Banner + My Profile + My Goal
//
// Extracted from FamilyView. Enhanced with:
//   - CapabilityBadge instead of RoleBadge
//   - Goal empty state CTA with suggestions
//   - Modern syntax (.now, LocalizedStringKey, etc.)
//
// ============================================================================

import SwiftUI
import PhotosUI

// MARK: - Family Banner (Section 1)

struct MeBannerSection: View {
    let family: Family?
    @Binding var selectedPhoto: PhotosPickerItem?
    let isUploading: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Banner image
            ZStack {
                if let bannerURL = family?.bannerURL,
                   let url = URL(string: bannerURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(height: 160)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.themeSurfacePrimary.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if isUploading {
                        ProgressView()
                            .tint(.textOnAccent)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.textOnAccent)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentPrimary.opacity(0.85)))
            }
            .padding(DS.Spacing.lg)

            // Family name overlay
            if let name = family?.name {
                VStack {
                    Spacer()
                    HStack {
                        Text(name)
                            .font(DS.Typography.heading())
                            .foregroundStyle(.textPrimary)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    .padding(.bottom, DS.Spacing.sm)
                }
            }
        }
    }

    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: [Color.accentPrimary.opacity(0.2), Color.accentSecondary.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - My Profile (Section 2)

struct MeProfileSection: View {
    let user: FamilyUser
    let onEditProfile: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Avatar with edit pencil
            ZStack(alignment: .bottomTrailing) {
                AvatarView(user: user, size: 70)

                Button(action: onEditProfile) {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.textOnAccent)
                        .padding(DS.Spacing.sm)
                        .background(Circle().fill(Color.accentPrimary))
                }
                .offset(x: 4, y: 4)
            }

            // Name + preset badge
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(user.displayName)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)

                CapabilityBadge(preset: user.resolvedPreset)
            }

            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }
}

// MARK: - My Goal (Section 3)

struct MeGoalSection: View {
    let goal: String?
    let currentYear: String
    let onEditGoal: () -> Void

    var body: some View {
        if let goal, !goal.isEmpty {
            // Goal exists — show it
            goalCard(goal)
        } else {
            // Empty state — CTA to set a goal
            emptyGoalCTA
        }
    }

    private func goalCard(_ goal: String) -> some View {
        Button(action: onEditGoal) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "target")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(AppStrings.goalForYear(currentYear))
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)

                    Text(goal)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.accentPrimary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.accentPrimary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyGoalCTA: some View {
        Button(action: onEditGoal) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "target")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("set_a_goal")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)

                    Text("set_a_goal_subtitle")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentPrimary)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(
                        Color.accentPrimary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
