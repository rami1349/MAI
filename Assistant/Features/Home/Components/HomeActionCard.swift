// ============================================================================
// HomeActionCard.swift
//
// SLOT 2: Action Card
//
// Shows the SINGLE most important pending action. One card max.
// Disappears once resolved. Most users see this 0–2 times per session.
//
// Priority (first match wins):
//   1. Homework pending review (if canVerifyHomework + pending tasks exist)
//   2. Overdue task (oldest overdue first)
//   3. Reward to claim (approved payout waiting)
//
// Design rule: Never shows a disabled state. If the user lacks the capability,
// the action card simply doesn't appear for that action type.
//
// ============================================================================

import SwiftUI

// MARK: - Action Card Data

/// The resolved action card to display — at most one per home screen render.
enum ActionCardData: Equatable, Identifiable {
    case reviewHomework(task: FamilyTask)
    case overdueTask(task: FamilyTask)
    case claimReward(amount: Double)
    
    var id: String {
        switch self {
        case .reviewHomework(let t): "review_\(t.stableId)"
        case .overdueTask(let t):    "overdue_\(t.stableId)"
        case .claimReward:           "claim_reward"
        }
    }
    
    /// Resolve the highest-priority action card.
    /// Returns nil when nothing needs attention — slot 2 collapses.
    static func resolve(
        capabilities: MemberCapabilities,
        pendingVerificationTasks: [FamilyTask],
        overdueTasks: [FamilyTask],
        pendingPayoutAmount: Double
    ) -> ActionCardData? {
        // 1. Homework to review (requires canVerifyHomework)
        if capabilities.canVerifyHomework,
           let firstPending = pendingVerificationTasks.first {
            return .reviewHomework(task: firstPending)
        }
        // 2. Overdue task
        if let firstOverdue = overdueTasks.first {
            return .overdueTask(task: firstOverdue)
        }
        // 3. Reward to claim
        if pendingPayoutAmount > 0 {
            return .claimReward(amount: pendingPayoutAmount)
        }
        return nil
    }
}

// MARK: - Action Card View

struct HomeActionCard: View {
    let data: ActionCardData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(DS.Typography.heading())
                        .foregroundStyle(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                    
                    Text(subtitle)
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Action indicator
                Image(systemName: "chevron.right")
                    .font(DS.Typography.body())
                    .foregroundStyle(iconColor)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(iconColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(iconColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.screenH)
    }
    
    // MARK: - Computed Display Properties
    
    private var iconName: String {
        switch data {
        case .reviewHomework: "checkmark.seal.fill"
        case .overdueTask:    "exclamationmark.triangle.fill"
        case .claimReward:    "dollarsign.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch data {
        case .reviewHomework: .accentOrange
        case .overdueTask:    .accentRed
        case .claimReward:    .accentGreen
        }
    }
    
    private var title: LocalizedStringKey {
        switch data {
        case .reviewHomework:
            "homework_to_review"
        case .overdueTask:
            "overdue_task_action"
        case .claimReward:
            "reward_to_claim"
        }
    }
    
    private var subtitle: String {
        switch data {
        case .reviewHomework(let task):
            AppStrings.localized("review_homework_subtitle") + " — \(task.title)"
        case .overdueTask(let task):
            task.title
        case .claimReward(let amount):
            AppStrings.earnedRewardClaim(amount.currencyString)
        }
    }
}
