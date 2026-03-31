// ============================================================================
// HomeGreetingSection.swift
//
// SLOT 1: Greeting + Daily Progress Ring + Stat
//
// ADHD UPGRADES (v3):
//   - Daily progress ring: visible dopamine target ("3 of 7 done")
//   - Streak flame: loss aversion motivator
//   - Relative stat line kept from v2
//
// ============================================================================

import SwiftUI

// MARK: - Personal Stat Model (unchanged)

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
    
    // ADHD: daily progress
    var todayCompleted: Int = 0
    var todayTotal: Int = 0

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Date
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)

                // Greeting + name
                HStack(spacing: DS.Spacing.md) {
                    Text("\(greetingText), \(userName)!")
                        .font(DS.Typography.displayMedium())
                        .foregroundStyle(.textPrimary)
                    
                    // ADHD: Daily progress ring
                    if todayTotal > 0 {
                        dailyProgressRing
                    }
                }

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
    
    // MARK: - Daily Progress Ring (ADHD)
    
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
        .padding(.top, DS.Spacing.xxs)
    }

    // MARK: - Greeting

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return AppStrings.localized("good_morning")
        case 12..<17: return AppStrings.localized("good_afternoon")
        default:      return AppStrings.localized("good_evening")
        }
    }
}
