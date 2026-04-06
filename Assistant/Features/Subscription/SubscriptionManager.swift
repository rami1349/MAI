//
//  SubscriptionManager.swift
//  Assistant
//  PRODUCT IDS (must match App Store Connect + validatePurchase.js):
//    Subscriptions (auto-renewable group "premium"):
//      - premium_monthly   ($9.99/mo)
//      - premium_yearly    ($79.99/yr — "Save 33%")
//    Consumables:
//      - credits_50        ($4.99  — 50 credits)
//      - credits_150       ($9.99  — 150 credits, "Best Value")
//      - credits_500       ($24.99 — 500 credits)
//

import StoreKit
import SwiftUI
import FirebaseFunctions
import FirebaseFirestore
import os

// Disambiguate StoreKit types from Firestore types
typealias StoreTransaction = StoreKit.Transaction
typealias StoreVerificationResult = StoreKit.VerificationResult

// MARK: - Product Identifiers

enum StoreProduct: Sendable {
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

struct CreditPackage: Identifiable, Sendable {
    let id: String
    let credits: Int
    let isBestValue: Bool
    var product: Product?

    var displayPrice: String { product?.displayPrice ?? "—" }
}

// MARK: - Subscription Manager

@MainActor
@Observable
final class SubscriptionManager {

    // MARK: - Public State

    var tier: SubscriptionTier = .free
    var aiCredits: Int = 0
    private(set) var subscriptionProducts: [Product] = []
    private(set) var creditProducts: [Product] = []
    var isPurchasing = false
    var purchaseError: String?
    var showPaywall = false
    var showCreditsPurchase = false

    // MARK: - Private

    @ObservationIgnored private var updateListenerTask: Task<Void, Never>?
    @ObservationIgnored private var userId: String?
    @ObservationIgnored private lazy var functions = Functions.functions(region: "us-west1")
    @ObservationIgnored private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app",
        category: "Store"
    )

    // MARK: - Tier Enum

    enum SubscriptionTier: String, Codable, Sendable {
        case free
        case premium

        var displayName: String {
            switch self {
            case .free:    String(localized: "free")
            case .premium: String(localized: "premium")
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

    func configure(userId: String, user: FamilyUser) {
        self.userId = userId
        self.tier = user.isPremium ? .premium : .free
        self.aiCredits = user.aiCredits ?? 0
        Self.logger.info("Configured: tier=\(self.tier.rawValue), credits=\(self.aiCredits)")
    }

    func reset() {
        userId = nil
        tier = .free
        aiCredits = 0
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: StoreProduct.allIDs)

            subscriptionProducts = products
                .filter { StoreProduct.subscriptionIDs.contains($0.id) }
                .sorted { $0.price < $1.price }

            creditProducts = products
                .filter { StoreProduct.creditIDs.contains($0.id) }
                .sorted { $0.price < $1.price }
        } catch {
            Self.logger.error("Failed to load products: \(error.localizedDescription)")
            CrashReporting.record(error, context: "SubscriptionManager.loadProducts")
        }
    }

    // MARK: - Credit Packages (for UI)

    var creditPackages: [CreditPackage] {
        [
            CreditPackage(id: StoreProduct.credits50,  credits: 50,  isBestValue: false,
                          product: creditProducts.first { $0.id == StoreProduct.credits50 }),
            CreditPackage(id: StoreProduct.credits150, credits: 150, isBestValue: true,
                          product: creditProducts.first { $0.id == StoreProduct.credits150 }),
            CreditPackage(id: StoreProduct.credits500, credits: 500, isBestValue: false,
                          product: creditProducts.first { $0.id == StoreProduct.credits500 }),
        ]
    }

    // MARK: - Purchase

    func purchaseSubscription(_ product: Product) async {
        await purchase(product)
    }

    func purchaseCredits(_ package: CreditPackage) async {
        guard let product = package.product else { return }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await validateOnServer(transaction)
                await transaction.finish()

            case .pending:
                isPurchasing = false
                purchaseError = String(localized: "purchase_pending")

            case .userCancelled:
                isPurchasing = false

            @unknown default:
                isPurchasing = false
            }
        } catch {
            isPurchasing = false
            purchaseError = error.localizedDescription
            CrashReporting.record(error, context: "SubscriptionManager.purchase")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlementState()
        } catch {
            purchaseError = String(localized: "restore_failed")
        }
    }

    // MARK: - Server Validation

    private func validateOnServer(_ transaction: StoreTransaction) async {
        do {
            let result = try await functions.httpsCallable("validatePurchase").call([
                "productId": transaction.productID,
                "transactionId": String(transaction.id),
                "originalTransactionId": String(transaction.originalID),
                "environment": transaction.environment.rawValue,
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool, success else {
                Self.logger.error("validatePurchase returned unexpected response")
                isPurchasing = false
                return
            }

            if let tierStr = data["tier"] as? String {
                tier = tierStr == "premium" ? .premium : .free
            }
            if let credits = data["aiCredits"] as? Int {
                aiCredits = credits
            }

            isPurchasing = false
            showPaywall = false
            showCreditsPurchase = false

            Self.logger.info("Purchase validated: tier=\(self.tier.rawValue), credits=\(self.aiCredits)")
            CrashReporting.log("Purchase validated: \(transaction.productID)")

        } catch {
            Self.logger.error("Server validation failed: \(error.localizedDescription)")
            CrashReporting.record(error, context: "SubscriptionManager.validateOnServer")
            isPurchasing = false
            purchaseError = String(localized: "purchase_validation_failed")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { @Sendable [weak self] in
            for await result in StoreTransaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.validateOnServer(transaction)
                    await transaction.finish()
                } catch {
                    await Self.logger.error("Unverified transaction update: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Entitlement Refresh

    func refreshEntitlementState() async {
        let isPremium = await checkForPremiumEntitlement()
        let newTier: SubscriptionTier = isPremium ? .premium : .free

        if newTier != tier {
            tier = newTier

            if !isPremium {
                do {
                    let result = try await functions.httpsCallable("expireSubscription").call([:])
                    if let data = result.data as? [String: Any],
                       let tierStr = data["tier"] as? String {
                        tier = tierStr == "premium" ? .premium : .free
                    }
                } catch {
                    Self.logger.error("Failed to sync expiry: \(error.localizedDescription)")
                }
            }
        }
    }

    private nonisolated func checkForPremiumEntitlement() async -> Bool {
        for await result in StoreTransaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if StoreProduct.subscriptionIDs.contains(transaction.productID) {
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    private nonisolated func checkVerified<T>(_ result: StoreVerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }

    private func creditAmount(for productID: String) -> Int {
        switch productID {
        case StoreProduct.credits50:  50
        case StoreProduct.credits150: 150
        case StoreProduct.credits500: 500
        default: 0
        }
    }

    // MARK: - AI Usage

    func canUseAI(remainingDaily: Int) -> Bool {
        remainingDaily > 0 || aiCredits > 0
    }

    func willUseCredit(remainingDaily: Int) -> Bool {
        remainingDaily <= 0 && aiCredits > 0
    }

    func consumeCredit() {
        if aiCredits > 0 { aiCredits -= 1 }
    }

    func reloadCredits() async {
        guard let userId else { return }
        do {
            let doc = try await Firestore.firestore()
                .collection("users").document(userId).getDocument()
            let serverCredits = doc.data()?["aiCredits"] as? Int ?? 0
            aiCredits = serverCredits
        } catch {
            Self.logger.error("Failed to reload credits: \(error.localizedDescription)")
        }
    }
}
