// ============================================================================
// HomeGreetingSection.swift
//
// SLOT 1: Greeting + Personal Stat
//
// Always visible. Shows the user's name + one contextual stat line.
// The stat is capability-driven, first match wins — zero role branching.
//
// Priority order:
//   1. canVerifyHomework AND pendingReviewCount > 0 → "X tasks waiting for review"
//   2. rewardEarnedThisWeek > 0 → "You earned $X this week!"
//   3. habitStreakDays > 0 → "X-day habit streak going strong"
//   4. Fallback → "Here's what's on your plate today"
//
// ============================================================================

import SwiftUI

// MARK: - Personal Stat Model

/// Data-driven personal stat — computed once per rebuild, displayed in the greeting.
enum PersonalStat: Equatable, Sendable {
    case pendingReviews(count: Int)
    case earnedThisWeek(amount: Double)
    case habitStreak(days: Int)
    case fallback

    /// Resolve the most relevant stat for this user.
    /// First match wins — no role checks, just data + capabilities.
    static func resolve(
        capabilities: MemberCapabilities,
        pendingReviewCount: Int,
        weeklyEarnings: Double,
        habitStreakDays: Int
    ) -> PersonalStat {
        if capabilities.canVerifyHomework && pendingReviewCount > 0 {
            return .pendingReviews(count: pendingReviewCount)
        }
        if weeklyEarnings > 0 {
            return .earnedThisWeek(amount: weeklyEarnings)
        }
        if habitStreakDays > 0 {
            return .habitStreak(days: habitStreakDays)
        }
        return .fallback
    }

    var icon: String {
        switch self {
        case .pendingReviews: "checkmark.seal"
        case .earnedThisWeek: "dollarsign.circle"
        case .habitStreak:    "flame"
        case .fallback:       "sparkles"
        }
    }

    var iconColor: Color {
        switch self {
        case .pendingReviews: .accentOrange
        case .earnedThisWeek: .accentGreen
        case .habitStreak:    .accentPrimary
        case .fallback:       .textTertiary
        }
    }
}

// MARK: - Greeting Section

struct HomeGreetingSection: View {
    let userName: String
    let stat: PersonalStat
    let unreadNotificationCount: Int
    let onNotificationsTapped: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Date
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)

                // Greeting + name
                Text("\(greetingKey), \(userName)!")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.textPrimary)

                // Personal stat
                statLine
            }

            Spacer()

            // Notification bell
            Button(action: onNotificationsTapped) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.themeCardBackground)
                                .elevation1()
                        )

                    if unreadNotificationCount > 0 {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }

    // MARK: - Stat Line

    @ViewBuilder
    private var statLine: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: stat.icon)
                .font(DS.Typography.caption())
                .foregroundStyle(stat.iconColor)

            switch stat {
            case .pendingReviews(let count):
                Text(AppStrings.tasksWaitingReview(count))
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(stat.iconColor)

            case .earnedThisWeek(let amount):
                Text(AppStrings.earnedThisWeekStat(amount.currencyString))
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(stat.iconColor)

            case .habitStreak(let days):
                Text(AppStrings.habitStreakGoing(days))
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(stat.iconColor)

            case .fallback:
                Text("heres_whats_on_your_plate")
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.top, DS.Spacing.xxs)
    }

    // MARK: - Greeting

    private var greetingKey: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return AppStrings.localized("good_morning")
        case 12..<17: return AppStrings.localized("good_afternoon")
        default:      return AppStrings.localized("good_evening")
        }
    }
}
