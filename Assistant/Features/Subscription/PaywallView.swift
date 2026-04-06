//
//  PaywallView.swift
//  Assistant
//
//  PURPOSE:
//    Subscription purchase screen. Displays the single real Premium benefit
//    (300 AI messages/day vs 20 free), monthly and yearly plan cards,
//    and handles the StoreKit purchase flow via SubscriptionManager.
//
//  ARCHITECTURE ROLE:
//    Leaf modal — presented from SettingsView and anywhere the app
//    gates a premium feature. Reads SubscriptionManager from
//    the environment. Delegates all purchase logic to the store.
//
//  DATA FLOW:
//    SubscriptionManager  → subscriptionProducts, isPurchasing,
//                           purchaseSubscription(), restorePurchases()
//
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SubscriptionManager.self) var store
    
    @State private var selectedPlan: Product?
    @State private var selectedLegalDocument: LegalDocument?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    heroSection
                    comparisonCard
                    planCards
                    purchaseButton
                    footerSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle("upgrade_to_premium")
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
            
            Text("unlock_full_mai")
                .font(DS.Typography.heading())
                .multilineTextAlignment(.center)
                .foregroundStyle(.textPrimary)
            
            Text("premium_subtitle")
                .font(DS.Typography.body())
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Free vs Premium Comparison
    
    private var comparisonCard: some View {
        VStack(spacing: 0) {
            // Free row
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("free")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                    Text("20")
                        .font(DS.Typography.displayMedium())
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                Text("messages_per_day")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.lg)
            
            Divider()
            
            // Premium row
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("premium")
                            .font(DS.Typography.caption())
                            .foregroundStyle(.accentPrimary)
                        Image(systemName: "crown.fill")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.accentPrimary)
                    }
                    Text("300")
                        .font(DS.Typography.displayMedium())
                        .foregroundStyle(.accentPrimary)
                }
                
                Spacer()
                
                Text("messages_per_day")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                
                Text("15x")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textOnAccent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(Color.accentPrimary))
            }
            .padding(DS.Spacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
        )
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
                            Text("save_33")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textOnAccent)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentGreen))
                        } else {
                            Color.clear.frame(height: 18)
                        }
                        
                        Text(isYearly ? "yearly" : "monthly")
                            .font(DS.Typography.label())
                            .foregroundStyle(.textPrimary)
                        
                        Text(product.displayPrice)
                            .font(DS.Typography.displayMedium())
                            .foregroundStyle(isSelected ? .accentPrimary : .textPrimary)
                        
                        Text(isYearly ? "per_year" : "per_month")
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textSecondary)
                        
                        if isYearly {
                            let monthly = product.price / 12
                            Text(monthly.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) + "/\(String(localized: "month_short"))")
                                .font(DS.Typography.caption())
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
                    Text("subscribe")
                        .font(DS.Typography.label())
                    if let plan = selectedPlan {
                        Text("· \(plan.displayPrice)")
                            .font(DS.Typography.label())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary))
            .foregroundStyle(.textOnAccent)
        }
        .disabled(selectedPlan == nil || store.isPurchasing)
        .opacity(selectedPlan == nil ? 0.5 : 1)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button("restore_purchases") {
                Task { await store.restorePurchases() }
            }
            .font(DS.Typography.bodySmall())
            .foregroundStyle(.accentPrimary)
            
            Text("payment_apple_id")
                .font(DS.Typography.micro())
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
            
            Text("subscription_auto_renews")
                .font(DS.Typography.micro())
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
            
            // Legal links — required by App Store Review Guidelines 3.1.2
            HStack(spacing: DS.Spacing.lg) {
                Button {
                    selectedLegalDocument = .privacyPolicy
                } label: {
                    Text("privacy_policy")
                        .font(DS.Typography.micro())
                        .foregroundStyle(.accentPrimary)
                }
                
                Text("·")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
                
                Button {
                    selectedLegalDocument = .termsOfService
                } label: {
                    Text("terms_of_service")
                        .font(DS.Typography.micro())
                        .foregroundStyle(.accentPrimary)
                }
            }
        }
        .sheet(item: $selectedLegalDocument) { doc in
            LegalView(document: doc)
                .presentationBackground(Color.themeSurfacePrimary)
        }
    }
}
