//
//  StatusBadge.swift
//  FamilyHub
//
//  Task status badge component
//  Status badge with refined typography
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct StatusBadge: View {
    let status: FamilyTask.TaskStatus
    let color: Color
    
    var body: some View {
        Text(statusText)
            .font(DS.Typography.captionMedium())
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
    }
    
    private var statusText: String {
        switch status {
        case .todo: return L10n.todo
        case .inProgress: return L10n.inProgress
        case .pendingVerification: return L10n.pendingVerification
        case .completed: return L10n.completed
        }
    }
}

// MARK: - Generic Badge Component

struct StyledBadge: View {
    let text: String
    var color: Color = Color.accentPrimary
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(DS.Typography.micro())
            }
            Text(text)
                .font(DS.Typography.captionMedium())
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.10))
        )
    }
}

// MARK: - Count Badge (for notifications, etc.)

struct CountBadge: View {
    let count: Int
    var color: Color = Color.accentRed
    
    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(DS.Typography.micro()) // was .rounded
                .foregroundStyle(.textOnAccent)
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(
                    Capsule()
                        .fill(color)
                )
        }
    }
}

#Preview {
    VStack(spacing: DS.Spacing.md) {
        // Status badges
        HStack(spacing: DS.Spacing.sm) {
            StatusBadge(status: .todo, color: Color.statusTodo)
            StatusBadge(status: .inProgress, color: Color.statusInProgress)
            StatusBadge(status: .pendingVerification, color: Color.statusPending)
            StatusBadge(status: .completed, color: Color.statusCompleted)
        }
        
        ThemeDivider()
        
        // Generic badges
        HStack(spacing: DS.Spacing.sm) {
            StyledBadge(text: "High", color: Color.accentOrange, icon: "exclamationmark.triangle.fill")
            StyledBadge(text: "Reward", color: Color.accentGreen, icon: "dollarsign.circle.fill")
            StyledBadge(text: "Recurring", color: Color.accentBlue, icon: "repeat")
        }
        
        ThemeDivider()
        
        // Count badges
        HStack(spacing: DS.Spacing.lg) {
            CountBadge(count: 3)
            CountBadge(count: 12)
            CountBadge(count: 150)
        }
    }
    .padding(DS.Spacing.lg)
    .background(Color.themeSurfacePrimary)
}
