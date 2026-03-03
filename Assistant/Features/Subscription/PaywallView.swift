//
//  PaywallView.swift
//  Assistant
//
//  Premium upgrade screen. Shown when user taps "Upgrade" from
//  the rate limit banner, settings, or anywhere else.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SubscriptionManager.self) var store
    
    @State private var selectedPlan: Product?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    heroSection
                    planCards
                    featuresSection
                    purchaseButton
                    footerSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle("Upgrade to Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .task {
                if store.subscriptionProducts.isEmpty {
                    await store.loadProducts()
                }
                // Default to yearly (better value)
                selectedPlan = store.subscriptionProducts.last
            }
            .globalErrorBanner(errorMessage: Binding(
                get: { store.purchaseError },
                set: { store.purchaseError = $0 }
            ))
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.accentPrimary)
            }
            .padding(.top, DS.Spacing.lg)
            
            Text("Unlock the full MAI experience")
                .font(DS.Typography.heading())
                .multilineTextAlignment(.center)
                .foregroundStyle(.textPrimary)
            
            Text("More messages, smarter AI, and unlimited potential for your family.")
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Plan Cards
    
    private var planCards: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(store.subscriptionProducts, id: \.id) { product in
                let isSelected = selectedPlan?.id == product.id
                let isYearly = product.id == StoreProduct.premiumYearly
                
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedPlan = product }
                    DS.Haptics.light()
                } label: {
                    VStack(spacing: DS.Spacing.sm) {
                        if isYearly {
                            Text("Save 33%")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentGreen))
                        } else {
                            Text(" ").font(DS.Typography.micro()).opacity(0)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                        }
                        
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(DS.Typography.body())
                            .fontWeight(.semibold)
                            .foregroundStyle(.textPrimary)
                        
                        Text(product.displayPrice)
                            .font(DS.Typography.displayMedium()) // was .rounded
                            .foregroundStyle(isSelected ? .accentPrimary : .textPrimary)
                        
                        Text(isYearly ? "per year" : "per month")
                            .font(DS.Typography.subheading())
                            .foregroundStyle(.textSecondary)
                        
                        if isYearly {
                            let monthly = product.price / 12
                            Text("\(monthly.formatted(.currency(code: "USD")))/mo")
                                .font(DS.Typography.subheading())
                                .foregroundStyle(.accentGreen)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(Color.themeCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(isSelected ? Color.accentPrimary : Color.themeCardBorder,
                                    lineWidth: isSelected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("What you get")
                .font(DS.Typography.body())
                .fontWeight(.semibold)
                .foregroundStyle(.textPrimary)
            
            featureRow(icon: "bubble.left.and.text.bubble.right.fill",
                       title: "300 messages/day",
                       subtitle: "vs 20 on Free", color: .accentPrimary)
            featureRow(icon: "brain.head.profile.fill",
                       title: "Smarter AI model",
                       subtitle: "GPT-4o for chat (vs GPT-4o-mini)", color: .purple)
            featureRow(icon: "person.3.fill",
                       title: "10 family members",
                       subtitle: "vs 4 on Free", color: .accentGreen)
            featureRow(icon: "checklist",
                       title: "200 active tasks",
                       subtitle: "vs 50 on Free", color: .orange)
            featureRow(icon: "chart.bar.fill",
                       title: "Advanced analytics",
                       subtitle: "Task completion trends & insights", color: .blue)
            featureRow(icon: "star.fill",
                       title: "Priority support",
                       subtitle: "Faster response times", color: .yellow)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
    }
    
    private func featureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(DS.Typography.body())
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.bodySmall())
                    .fontWeight(.medium)
                    .foregroundStyle(.textPrimary)
                Text(subtitle)
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textSecondary)
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            guard let plan = selectedPlan else { return }
            Task { await store.purchaseSubscription(plan) }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Subscribe")
                        .fontWeight(.bold)
                    if let plan = selectedPlan {
                        Text("· \(plan.displayPrice)")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary))
            .foregroundStyle(.white)
            .font(DS.Typography.body())
        }
        .disabled(selectedPlan == nil || store.isPurchasing)
        .opacity(selectedPlan == nil ? 0.5 : 1)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button("Restore Purchases") {
                Task { await store.restorePurchases() }
            }
            .font(DS.Typography.bodySmall())
            .foregroundStyle(.accentPrimary)
            
            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(DS.Typography.micro())
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}
