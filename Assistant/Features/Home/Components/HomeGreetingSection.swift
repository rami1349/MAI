// ============================================================================
// HomeGreetingSection.swift
//
// SLOT 1: Greeting + Progress + Weekly Wins
//
// Merges the old Weekly Wins section inline. Shows:
//   - Date + personalized greeting
//   - Daily progress ring (today's tasks)
//   - Personal stat line (context-aware)
//   - Weekly wins pills (completed, earned, streak)
//   - Notification bell
//
// ============================================================================

import SwiftUI

// MARK: - Personal Stat Model

enum PersonalStat: Equatable, Sendable {
    case pendingReviews(count: Int)
    case earnedThisWeek(amount: Double)
    case habitStreak(days: Int)
    case fallback

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

    // Daily progress
    var todayCompleted: Int = 0
    var todayTotal: Int = 0

    // Weekly wins (merged from old WeeklyWinsSection)
    var weeklyCompletedCount: Int = 0
    var weeklyEarnings: Double = 0
    var habitStreakDays: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Row 1: Greeting + Bell
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Date
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)

                    // Greeting + progress ring
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(greetingText), \(userName)!")
                            .font(DS.Typography.displayMedium())
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if todayTotal > 0 {
                            dailyProgressRing
                        }
                    }

                    // Stat line
                    statLine
                }

                Spacer(minLength: DS.Spacing.md)

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

            // Row 2: Weekly wins pills (inline)
            if hasWeeklyWins {
                weeklyWinsPills
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }

    // MARK: - Weekly Wins Pills

    private var hasWeeklyWins: Bool {
        weeklyCompletedCount > 0 || weeklyEarnings > 0 || habitStreakDays > 0
    }

    private var weeklyWinsPills: some View {
        HStack(spacing: DS.Spacing.sm) {
            if weeklyCompletedCount > 0 {
                WinPill(
                    icon: "checkmark.circle.fill",
                    text: AppStrings.xDone(weeklyCompletedCount),
                    color: .accentPrimary
                )
            }

            if weeklyEarnings > 0 {
                WinPill(
                    icon: "dollarsign.circle.fill",
                    text: weeklyEarnings.currencyString,
                    color: .accentGreen
                )
            }

            if habitStreakDays > 0 {
                WinPill(
                    icon: "flame.fill",
                    text: "\(habitStreakDays)\(String(localized: "d_short"))",
                    color: .accentOrange
                )
            }

            Spacer()
        }
    }

    // MARK: - Daily Progress Ring

    private var dailyProgressRing: some View {
        let progress = todayTotal > 0 ? Double(todayCompleted) / Double(todayTotal) : 0
        let allDone = todayCompleted >= todayTotal && todayTotal > 0
        let ringColor: Color = allDone ? .accentGreen : .accentPrimary

        return HStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 3)
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))

                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ringColor)
                }
            }

            Text("\(todayCompleted)/\(todayTotal)")
                .font(DS.Typography.captionMedium())
                .foregroundStyle(allDone ? .accentGreen : .textSecondary)
        }
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
    }

    // MARK: - Greeting Text

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return AppStrings.localized("good_morning")
        case 12..<17: return AppStrings.localized("good_afternoon")
        default:      return AppStrings.localized("good_evening")
        }
    }
}

// MARK: - Win Pill (compact inline badge)

private struct WinPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)

            Text(text)
                .font(DS.Typography.captionMedium())
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
        )
    }
}
