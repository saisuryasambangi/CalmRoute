//
//  StoreService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  StoreKit 2 service for the CalmRoute Pro non-consumable unlock.
//
//  Product ID: com.saisuryasambangi.calmroute.pro
//
//  Pro features unlocked:
//    - Unlimited saved routes
//    - Custom stress colour themes
//    - GPX export
//

import Foundation
import StoreKit

@MainActor
final class StoreService: ObservableObject {

    static let shared = StoreService()

    // MARK: - Published state

    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var purchaseError: String?
    @Published var isPurchasing: Bool = false

    // MARK: - Constants

    private static let proProductID = "com.saisuryasambangi.calmroute.pro"

    // MARK: - Init

    private init() {
        Task {
            await checkEntitlements()
            await loadProducts()
        }
    }

    // MARK: - Product loading

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.proProductID])
        } catch {
            print("[StoreService] Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase() async throws {
        guard let product = products.first(where: { $0.id == Self.proProductID }) else {
            throw StoreError.productNotFound
        }

        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await fulfil(transaction)

        case .userCancelled:
            break  // No error — user chose not to buy.

        case .pending:
            // Awaiting parent approval, Ask to Buy, etc.
            print("[StoreService] Purchase pending external approval")

        @unknown default:
            throw StoreError.unknownPurchaseResult
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            print("[StoreService] Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Entitlement check

    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.proProductID {
                isPro = true
                return
            }
        }
        isPro = false
    }

    // MARK: - Helpers

    private func fulfil(_ transaction: Transaction) async {
        if transaction.productID == Self.proProductID {
            isPro = true
        }
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.verificationFailed
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case productNotFound
    case verificationFailed
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productNotFound:      return "CalmRoute Pro is not available right now."
        case .verificationFailed:   return "Purchase verification failed. Please try again."
        case .unknownPurchaseResult: return "An unexpected error occurred."
        }
    }
}
