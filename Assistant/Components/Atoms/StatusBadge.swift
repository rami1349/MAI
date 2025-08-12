//
//  StatusBadge.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Task status badge component
//  UPDATED: Luxury typography and softer styling
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct StatusBadge: View {
    let status: FamilyTask.TaskStatus
    let color: Color
    
    var body: some View {
        Text(statusText)
            .font(Luxury.Typography.captionMedium())
            .foregroundColor(color)
            .padding(.horizontal, Luxury.Spacing.sm)
            .padding(.vertical, Luxury.Spacing.xxs)
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

struct LuxuryBadge: View {
    let text: String
    var color: Color = .accentPrimary
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: Luxury.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(Luxury.Typography.captionMedium())
        }
        .foregroundColor(color)
        .padding(.horizontal, Luxury.Spacing.sm)
        .padding(.vertical, Luxury.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.10))
        )
    }
}

// MARK: - Count Badge (for notifications, etc.)

struct CountBadge: View {
    let count: Int
    var color: Color = .accentRed
    
    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
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
    VStack(spacing: Luxury.Spacing.md) {
        // Status badges
        HStack(spacing: Luxury.Spacing.sm) {
            StatusBadge(status: .todo, color: .statusTodo)
            StatusBadge(status: .inProgress, color: .statusInProgress)
            StatusBadge(status: .pendingVerification, color: .statusPending)
            StatusBadge(status: .completed, color: .statusCompleted)
        }
        
        LuxuryDivider()
        
        // Generic badges
        HStack(spacing: Luxury.Spacing.sm) {
            LuxuryBadge(text: "High", color: .accentOrange, icon: "exclamationmark.triangle.fill")
            LuxuryBadge(text: "Reward", color: .accentGreen, icon: "dollarsign.circle.fill")
            LuxuryBadge(text: "Recurring", color: .accentBlue, icon: "repeat")
        }
        
        LuxuryDivider()
        
        // Count badges
        HStack(spacing: Luxury.Spacing.lg) {
            CountBadge(count: 3)
            CountBadge(count: 12)
            CountBadge(count: 150)
        }
    }
    .padding(Luxury.Spacing.lg)
    .background(Color.themeSurfacePrimary)
}