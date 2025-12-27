//
//  StoreManager.swift
//  Kashout
//
//  StoreKit 2 subscription management
//

import Foundation
import StoreKit

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {

    // MARK: - Published Properties

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var lastError: StoreError?

    // MARK: - Computed Properties

    /// Whether the user has an active Pro subscription
    var isProSubscriber: Bool {
        purchasedProductIDs.contains(Constants.StoreKit.proMonthlyProductID) ||
        purchasedProductIDs.contains(Constants.StoreKit.proYearlyProductID)
    }

    /// Monthly subscription product
    var monthlyProduct: Product? {
        products.first { $0.id == Constants.StoreKit.proMonthlyProductID }
    }

    /// Yearly subscription product
    var yearlyProduct: Product? {
        products.first { $0.id == Constants.StoreKit.proYearlyProductID }
    }

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?
    private let productIDs: Set<String> = [
        Constants.StoreKit.proMonthlyProductID,
        Constants.StoreKit.proYearlyProductID
    ]

    // MARK: - Singleton

    static let shared = StoreManager()

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check entitlements
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    /// Fetches subscription products from the App Store
    func loadProducts() async {
        isLoading = true
        lastError = nil

        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
            lastError = .productLoadFailed(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product
    /// - Parameter product: The product to purchase
    /// - Returns: Whether the purchase was successful
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        lastError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isLoading = false
                return true

            case .userCancelled:
                print("User cancelled purchase")
                isLoading = false
                return false

            case .pending:
                print("Purchase pending approval")
                lastError = .purchasePending
                isLoading = false
                return false

            @unknown default:
                print("Unknown purchase result")
                isLoading = false
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            lastError = .purchaseFailed(error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restores previously purchased subscriptions
    func restorePurchases() async {
        isLoading = true
        lastError = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
            lastError = .restoreFailed(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Update Purchased Products

    /// Updates the set of purchased product IDs based on current entitlements
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if subscription is still valid
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }

        purchasedProductIDs = purchased
        print("Updated purchased products: \(purchased)")
    }

    // MARK: - Transaction Listener

    /// Listens for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    /// Verifies a transaction result
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw StoreError.verificationFailed(error.localizedDescription)
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Subscription Status

    /// Gets the current subscription status for a product
    func subscriptionStatus(for productID: String) async -> Product.SubscriptionInfo.Status? {
        guard let product = products.first(where: { $0.id == productID }),
              let subscription = product.subscription else {
            return nil
        }

        do {
            let statuses = try await subscription.status
            return statuses.first
        } catch {
            print("Failed to get subscription status: \(error)")
            return nil
        }
    }

    /// Gets the renewal date for active subscription
    func subscriptionRenewalDate() async -> Date? {
        for productID in productIDs {
            if let status = await subscriptionStatus(for: productID),
               case .verified(let renewalInfo) = status.renewalInfo,
               status.state == .subscribed {
                return renewalInfo.expirationDate
            }
        }
        return nil
    }
}

// MARK: - Store Error

enum StoreError: Error, LocalizedError {
    case productLoadFailed(String)
    case purchaseFailed(String)
    case purchasePending
    case restoreFailed(String)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .productLoadFailed(let message):
            return "Failed to load products: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .purchasePending:
            return "Purchase is pending approval."
        case .restoreFailed(let message):
            return "Failed to restore purchases: \(message)"
        case .verificationFailed(let message):
            return "Transaction verification failed: \(message)"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    /// Formatted price string
    var formattedPrice: String {
        displayPrice
    }

    /// Subscription period description
    var periodDescription: String? {
        guard let subscription = subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "Daily" : "\(subscription.subscriptionPeriod.value) Days"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "Weekly" : "\(subscription.subscriptionPeriod.value) Weeks"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "Monthly" : "\(subscription.subscriptionPeriod.value) Months"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "Yearly" : "\(subscription.subscriptionPeriod.value) Years"
        @unknown default:
            return nil
        }
    }
}
