//
//  CreditsPurchaseSheet.swift
//  Assistant
//
//  v2: All strings localized, modern iOS 18.6 syntax
//
//  WHAT CHANGED (v1 → v2):
//    - "credits", "per credit", "Best Value" → localization keys
//    - camelCase keys → snake_case
//    - Hardcoded "$X.XX/credit" uses user's locale currency format
//    - Modern Swift 6 concurrency patterns
//
//
//
//  PURPOSE:
//    Credit purchase sheet. Shows available credit packages with
//    prices and a buy button. Includes upgrade-to-premium upsell.
//
//  ARCHITECTURE ROLE:
//    Modal sheet — presented when user needs more AI credits.
//    Reads SubscriptionManager for packages and purchase flow.
//
//  DATA FLOW:
//    SubscriptionManager → creditPackages, purchaseCredits()
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

                    Text("need_more_messages")
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)

                    Text("credits_never_expire")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.lg)

                // Current balance
                if store.aiCredits > 0 {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color.accentGreen)
                            .frame(width: 6, height: 6)
                        Text("\(store.aiCredits) \(String(localized: "credits_remaining"))")
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
                            Text("buy_credits")
                                .font(DS.Typography.label())
                            if let pkg = selectedPackage {
                                Text("· \(pkg.displayPrice)")
                                    .font(DS.Typography.label())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary))
                    .foregroundStyle(.textOnAccent)
                }
                .disabled(selectedPackage == nil || store.isPurchasing)
                .opacity(selectedPackage == nil ? 0.5 : 1)
                .padding(.horizontal, DS.Spacing.lg)

                // Or upgrade
                if !store.tier.isPremium {
                    Button {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.3))
                            store.showPaywall = true
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "sparkles")
                                .font(DS.Typography.body())
                            Text("or_upgrade_to_premium")
                                .font(DS.Typography.bodySmall())
                        }
                        .foregroundStyle(.accentPrimary)
                    }
                }

                Spacer()
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle("buy_credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DS.Typography.heading())
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .task {
                if store.creditProducts.isEmpty {
                    await store.loadProducts()
                }
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
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(pkg.credits)")
                            .font(DS.Typography.stat())
                            .foregroundStyle(.textPrimary)
                        Text("credits")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.textSecondary)

                        if pkg.isBestValue {
                            Text("best_value")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textOnAccent)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentGreen))
                        }
                    }

                    if pkg.credits > 0, let product = pkg.product {
                        let perCredit = product.price / Decimal(pkg.credits)
                        Text("\(perCredit.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) / \(String(localized: "credit"))")
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textTertiary)
                    }
                }

                Spacer()

                Text(pkg.displayPrice)
                    .font(DS.Typography.heading())
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
