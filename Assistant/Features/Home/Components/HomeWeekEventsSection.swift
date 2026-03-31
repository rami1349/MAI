// ============================================================================
// HomeWeeklyWinsSection.swift
//
// SLOT 8: Weekly Wins (ADHD Dopamine Reward)
//
// Shows a compact summary of the week's accomplishments.
// Designed to provide closure and motivation to keep going.
// Only appears when there's at least one win to celebrate.
//
// ============================================================================

import SwiftUI

struct HomeWeeklyWinsSection: View {
    let completedCount: Int
    let earnings: Double
    let streakDays: Int
    
    private var hasContent: Bool {
        completedCount > 0 || earnings > 0 || streakDays > 0
    }
    
    @ViewBuilder
    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(DS.Typography.label())
                        .foregroundStyle(.accentGreen)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentGreen.opacity(0.1))
                        )
                    
                    Text("weekly_wins")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                }
                
                // Stats row
                HStack(spacing: DS.Spacing.md) {
                    if completedCount > 0 {
                        WinPill(
                            icon: "checkmark.circle.fill",
                            value: "\(completedCount)",
                            label: "done",
                            color: .accentPrimary
                        )
                    }
                    
                    if earnings > 0 {
                        WinPill(
                            icon: "dollarsign.circle.fill",
                            value: earnings.currencyString,
                            label: "earned",
                            color: .accentGreen
                        )
                    }
                    
                    if streakDays > 0 {
                        WinPill(
                            icon: "flame.fill",
                            value: "\(streakDays)d",
                            label: "streak",
                            color: .accentOrange
                        )
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.accentGreen.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Win Pill

private struct WinPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(DS.Typography.heading())
                .foregroundStyle(color)
            
            Text(value)
                .font(DS.Typography.stat())
                .foregroundStyle(.textPrimary)
            
            Text(LocalizedStringKey(label))
                .font(DS.Typography.micro())
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
