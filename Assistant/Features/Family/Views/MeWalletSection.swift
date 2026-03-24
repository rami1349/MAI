// ============================================================================
// MeWalletSection.swift
//
// ME TAB section 4: My Wallet
//
// Promoted from a button (FamilyView) to an inline display.
// Balance visible in 1 tap. Hero moment for kids.
//
// Shows:
//   - Current balance (large, green)
//   - Pending payout count badge (if canApprovePayouts)
//   - "View History" button → RewardWalletView sheet
//
// ============================================================================

import SwiftUI

struct MeWalletSection: View {
    let balance: Double
    let pendingPayoutCount: Int
    let canApprovePayouts: Bool
    let onViewHistory: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentGreen)

                Text("my_wallet")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Spacer()

                // Pending payout badge (for parents)
                if canApprovePayouts && pendingPayoutCount > 0 {
                    Text(AppStrings.xToReview(pendingPayoutCount))
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textOnAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Capsule().fill(Color.accentRed))
                }
            }

            // Balance display
            HStack(alignment: .firstTextBaseline) {
                Text(balance.currencyString)
                    .font(DS.Typography.displayLarge())
                    .foregroundStyle(.accentGreen)
                    .contentTransition(.numericText())

                Spacer()
            }

            // View History button
            Button(action: onViewHistory) {
                HStack {
                    Text("view_wallet_history")
                        .font(DS.Typography.label())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(.accentPrimary)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(Color.accentPrimary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .stroke(Color.accentGreen.opacity(0.15), lineWidth: 1)
        )
        .elevation1()
    }
}
