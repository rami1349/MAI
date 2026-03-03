//
//  CreditsPurchaseSheet.swift
//  Assistant
//
//  Created by Ramiro  on 3/1/26.
//
//  Shown when free user hits daily limit. Offers:
//  1) Buy a credits pack (one-time, never expire)
//  2) Upgrade to Premium instead
//

import SwiftUI

struct CreditsPurchaseSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SubscriptionManager.self) var store
    
    @State private var selectedPackage: CreditPackage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "bolt.fill")
                            .font(DS.Typography.displayMedium())
                            .foregroundStyle(.statusWarning)
                    }
                    
                    Text("Need more messages?")
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)
                    
                    Text("Buy credits to keep chatting. Credits never expire.")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.lg)
                
                // Current balance
                if store.aiCredits > 0 {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "circle.fill")
                            .font(DS.Typography.micro()) // DT-exempt: tiny indicator
                            .foregroundStyle(.accentGreen)
                        Text("\(store.aiCredits) credits remaining")
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textSecondary)
                    }
                }
                
                // Credit packages
                VStack(spacing: DS.Spacing.md) {
                    ForEach(store.creditPackages) { pkg in
                        creditPackageRow(pkg)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                
                // Buy button
                Button {
                    guard let pkg = selectedPackage else { return }
                    Task { await store.purchaseCredits(pkg) }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if store.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Buy Credits")
                                .fontWeight(.bold)
                            if let pkg = selectedPackage {
                                Text("· \(pkg.displayPrice)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary))
                    .foregroundStyle(.textOnAccent)
                    .font(DS.Typography.body())
                }
                .disabled(selectedPackage == nil || store.isPurchasing)
                .opacity(selectedPackage == nil ? 0.5 : 1)
                .padding(.horizontal, DS.Spacing.lg)
                
                // Or upgrade
                if !store.tier.isPremium {
                    Button {
                        dismiss()
                        // Small delay so sheet dismisses first
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.3))
                            store.showPaywall = true
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "sparkles")
                                .font(DS.Typography.body())
                            Text("Or upgrade to Premium for 300/day")
                                .font(DS.Typography.bodySmall())
                        }
                        .foregroundStyle(.accentPrimary)
                    }
                }
                
                Spacer()
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle("Buy Credits")
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
                if store.creditProducts.isEmpty {
                    await store.loadProducts()
                }
                // Default to best value
                selectedPackage = store.creditPackages.first { $0.isBestValue }
            }
            .globalErrorBanner(errorMessage: Binding(
                get: { store.purchaseError },
                set: { store.purchaseError = $0 }
            ))
        }
    }
    
    // MARK: - Package Row
    
    private func creditPackageRow(_ pkg: CreditPackage) -> some View {
        let isSelected = selectedPackage?.id == pkg.id
        
        return Button {
            withAnimation(.spring(response: 0.3)) { selectedPackage = pkg }
            DS.Haptics.light()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Credits count
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(pkg.credits)")
                            .font(DS.Typography.stat()) // was .rounded
                            .foregroundStyle(.textPrimary)
                        Text("credits")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.textSecondary)
                        
                        if pkg.isBestValue {
                            Text("Best Value")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textOnAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentGreen))
                        }
                    }
                    
                    if pkg.credits > 0, let product = pkg.product {
                        let perCredit = product.price / Decimal(pkg.credits)
                        Text("\(perCredit.formatted(.currency(code: "USD")))/credit")
                            .font(DS.Typography.subheading())
                            .foregroundStyle(.textTertiary)
                    }
                }
                
                Spacer()
                
                // Price
                Text(pkg.displayPrice)
                    .font(DS.Typography.heading()) // was .rounded
                    .foregroundStyle(isSelected ? .accentPrimary : .textPrimary)
            }
            .padding(DS.Spacing.lg)
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
