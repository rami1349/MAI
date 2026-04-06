//
//  AIUsageBanner.swift
//  Assistant
//
//  Inline banner shown in AIChatView when:
//    1. Usage is getting low (≤ 5 remaining)
//    2. Daily limit reached (shows credit option or upgrade)
//    3. Using credits (subtle indicator)
//
//  NOTE: The new AIChatView already handles these banners inline.
//  This file is kept for optional reuse elsewhere (e.g. HomeView).
//

import SwiftUI

struct AIUsageBanner: View {
    
    @Environment(SubscriptionManager.self) var store
    
    /// Daily remaining passed in from the chat view model
    var remainingDaily: Int
    var dailyLimit: Int
    
    var body: some View {
        if remainingDaily <= 0 && store.aiCredits <= 0 {
            limitReachedBanner
        } else if remainingDaily <= 0 && store.aiCredits > 0 {
            usingCreditsBanner
        } else if remainingDaily <= 5 && remainingDaily > 0 {
            lowUsageBanner
        }
    }
    
    // MARK: - Limit Reached
    
    private var limitReachedBanner: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.statusWarning)
                
                Text(AppStrings.usedAllDailyAiActions(dailyLimit))
                    .font(.caption)
                    .foregroundStyle(.textPrimary)
            }
            
            HStack(spacing: DS.Spacing.md) {
                Button {
                    store.showCreditsPurchase = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("get_credits")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.accentPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.accentPrimary.opacity(0.1))
                    )
                }
                
                if !store.tier.isPremium {
                    Button {
                        store.showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                            Text("upgrade")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.textOnAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.accentPrimary)
                        )
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.Spacing.lg)
    }
    
    // MARK: - Using Credits
    
    private var usingCreditsBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.caption2)
                .foregroundStyle(.accentPrimary)
            
            Text(AppStrings.usingCreditsRemaining(store.aiCredits))
                .font(.caption)
                .foregroundStyle(.textSecondary)
            
            Spacer()
            
            Button {
                store.showCreditsPurchase = true
            } label: {
                Text("get_more")
                    .font(.caption)
                    .foregroundStyle(.accentPrimary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }
    
    // MARK: - Low Usage Warning
    
    private var lowUsageBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "gauge.low")
                .font(.caption)
                .foregroundStyle(.statusWarning)
            
            Text(AppStrings.actionsLeftToday(remainingDaily))
                .font(.caption)
                .foregroundStyle(.textSecondary)
            
            Spacer()
            
            if !store.tier.isPremium {
                Button {
                    store.showPaywall = true
                } label: {
                    Text("upgrade")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.accentPrimary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }
}
