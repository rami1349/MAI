//
//  SubscriptionManager.swift
//  Assistant
//
//  StoreKit 2 manager for subscriptions + credit purchases.
//
//  PRODUCT IDS (must match App Store Connect):
//    Subscriptions (auto-renewable group "premium"):
//      - premium_monthly   ($9.99/mo)
//      - premium_yearly    ($79.99/yr — "Save 33%")
//    Consumables:
//      - credits_50        ($4.99  — 50 credits)
//      - credits_150       ($9.99  — 150 credits, "Best Value")
//      - credits_500       ($24.99 — 500 credits)
//
//  ARCHITECTURE:
//    SubscriptionManager is an @Observable singleton injected via .environment().
//    It owns the Transaction.updates listener and syncs entitlement state
//    to Firestore via AuthViewModel.
//

import StoreKit
import SwiftUI
import os

// Disambiguate StoreKit types from FirebaseFirestore.Transaction / VerificationResult
typealias StoreTransaction = StoreKit.Transaction
typealias StoreVerificationResult = StoreKit.VerificationResult

// MARK: - Product Identifiers

enum StoreProduct {
    static let premiumMonthly  = "premium_monthly"
    static let premiumYearly   = "premium_yearly"
    
    static let credits50       = "credits_50"
    static let credits150      = "credits_150"
    static let credits500      = "credits_500"
    
    static let subscriptionIDs: Set<String> = [premiumMonthly, premiumYearly]
    static let creditIDs: Set<String>       = [credits50, credits150, credits500]
    static let allIDs: Set<String>          = subscriptionIDs.union(creditIDs)
}

// MARK: - Credit Package Display Info

struct CreditPackage: Identifiable {
    let id: String
    let credits: Int
    let isBestValue: Bool
    var product: Product?
    
    var displayPrice: String { product?.displayPrice ?? "—" }
}

// MARK: - Subscription Manager

@Observable
final class SubscriptionManager {
    
    // MARK: State
    
    /// Current subscription tier
    var tier: SubscriptionTier = .free
    
    /// AI credits balance (synced from Firestore, decremented locally for optimism)
    var aiCredits: Int = 0
    
    /// Loaded StoreKit products
    private(set) var subscriptionProducts: [Product] = []
    private(set) var creditProducts: [Product] = []
    
    /// Purchase in progress
    var isPurchasing = false
    var purchaseError: String?
    
    /// Whether the paywall / credits sheet is showing
    var showPaywall = false
    var showCreditsPurchase = false
    
    // MARK: Private
    
    private var updateListenerTask: Task<Void, Never>?
    private var onEntitlementChange: ((SubscriptionTier, Int) -> Void)?
    
    // MARK: - Tier Enum
    
    enum SubscriptionTier: String, Codable {
        case free
        case premium
        
        var displayName: String {
            switch self {
            case .free: return "Free"
            case .premium: return "Premium"
            }
        }
        
        var isPremium: Bool { self == .premium }
    }
    
    // MARK: - Lifecycle
    
    init() {
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /// Call once after auth to wire Firestore sync
    func configure(
        tier: SubscriptionTier,
        credits: Int,
        onEntitlementChange: @escaping (SubscriptionTier, Int) -> Void
    ) {
        self.tier = tier
        self.aiCredits = credits
        self.onEntitlementChange = onEntitlementChange
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: StoreProduct.allIDs)
            
            await MainActor.run {
                subscriptionProducts = products
                    .filter { StoreProduct.subscriptionIDs.contains($0.id) }
                    .sorted { $0.price < $1.price }  // monthly first
                
                creditProducts = products
                    .filter { StoreProduct.creditIDs.contains($0.id) }
                    .sorted { $0.price < $1.price }
            }
        } catch {
            Log.store.error("StoreKit: Failed to load products: \(error, privacy: .public)")
        }
    }
    
    // MARK: - Credit Packages (for UI)
    
    var creditPackages: [CreditPackage] {
        let definitions: [(id: String, credits: Int, best: Bool)] = [
            (StoreProduct.credits50, 50, false),
            (StoreProduct.credits150, 150, true),
            (StoreProduct.credits500, 500, false),
        ]
        
        return definitions.map { def in
            CreditPackage(
                id: def.id,
                credits: def.credits,
                isBestValue: def.best,
                product: creditProducts.first { $0.id == def.id }
            )
        }
    }
    
    // MARK: - Purchase Subscription
    
    func purchaseSubscription(_ product: Product) async {
        await purchase(product)
    }
    
    // MARK: - Purchase Credits
    
    func purchaseCredits(_ package: CreditPackage) async {
        guard let product = package.product else { return }
        await purchase(product)
    }
    
    // MARK: - Core Purchase
    
    private func purchase(_ product: Product) async {
        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
                
            case .pending:
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Purchase is pending approval."
                }
                
            case .userCancelled:
                await MainActor.run { isPurchasing = false }
                
            @unknown default:
                await MainActor.run { isPurchasing = false }
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                purchaseError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlementState()
        } catch {
            await MainActor.run {
                purchaseError = "Couldn't restore purchases. Please try again."
            }
        }
    }
    
    // MARK: - Transaction Handling
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { @Sendable [weak self] in
            for await result in StoreTransaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                } catch {
                    Log.store.error("StoreKit: Unverified transaction: \(error, privacy: .public)")
                }
            }
        }
    }
    
    private func handleTransaction(_ transaction: StoreTransaction) async {
        if StoreProduct.subscriptionIDs.contains(transaction.productID) {
            await MainActor.run {
                tier = .premium
                isPurchasing = false
                showPaywall = false
            }
            onEntitlementChange?(.premium, aiCredits)
            
        } else if StoreProduct.creditIDs.contains(transaction.productID) {
            let creditsToAdd = creditAmount(for: transaction.productID)
            await MainActor.run {
                aiCredits += creditsToAdd
                isPurchasing = false
                showCreditsPurchase = false
            }
            onEntitlementChange?(tier, aiCredits)
        }
    }
    
    /// Refresh entitlement from current entitlements (on app launch)
    func refreshEntitlementState() async {
        // Use a Sendable-safe local let instead of a captured var
        let isPremium = await checkForPremiumEntitlement()
        
        await MainActor.run {
            tier = isPremium ? .premium : .free
        }
        onEntitlementChange?(tier, aiCredits)
    }
    
    /// Iterate current entitlements and return whether premium is active.
    /// Isolated to avoid capturing a mutable var across concurrency boundaries.
    private func checkForPremiumEntitlement() async -> Bool {
        for await result in StoreTransaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if StoreProduct.subscriptionIDs.contains(transaction.productID) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Helpers
    
    private func checkVerified<T>(_ result: StoreVerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
    
    private func creditAmount(for productID: String) -> Int {
        switch productID {
        case StoreProduct.credits50:  return 50
        case StoreProduct.credits150: return 150
        case StoreProduct.credits500: return 500
        default: return 0
        }
    }
    
    // MARK: - Availability Check
    
    /// Whether the user can send a message (daily quota OR credits)
    func canUseAI(remainingDaily: Int) -> Bool {
        remainingDaily > 0 || aiCredits > 0
    }
    
    /// Whether this message will consume a credit
    func willUseCredit(remainingDaily: Int) -> Bool {
        remainingDaily <= 0 && aiCredits > 0
    }
    
    /// Consume one credit locally (optimistic)
    func consumeCredit() {
        if aiCredits > 0 { aiCredits -= 1 }
    }
}
