import Foundation
import StoreKit
import Combine

/// Kullanıcının hangi yolla Premium olduğunu belirtir.
enum PremiumPlan {
    case monthly
    case lifetime
}

@MainActor
final class StoreManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published private(set) var activePlan: PremiumPlan?
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseErrorMessage: String?

    // Değiştirmeyi unutmayın: App Store Connect'teki Product ID'lerle birebir aynı olmalı.
    let monthlyProductId  = "com.udfconverter.premium"           // Otomatik yenilenen abonelik
    let lifetimeProductId = "com.udfconverter.premium.lifetime"  // Tek seferlik (Non-Consumable)

    private var premiumProductIds: Set<String> { [monthlyProductId, lifetimeProductId] }

    private var updatesTask: Task<Void, Never>? = nil

    init() {
        updatesTask = listenForTransactions()
        Task {
            await checkPremiumStatus()
            await fetchProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    if let transaction = transaction {
                        await transaction.finish()
                        // Tek doğruluk kaynağı: her değişiklikte hakları baştan hesapla.
                        await self?.checkPremiumStatus()
                    }
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: Array(premiumProductIds))
            // Sabit sıra: önce aylık abonelik, sonra ömür boyu.
            let order = [monthlyProductId, lifetimeProductId]
            self.products = storeProducts.sorted {
                (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
            }
        } catch {
            print("Failed product fetch: \(error)")
        }
    }

    func purchase(_ product: Product) async throws {
        isPurchasing = true
        purchaseErrorMessage = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            let transaction = try checkVerified(verificationResult)
            await transaction.finish()
            await checkPremiumStatus()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func checkPremiumStatus() async {
        var hasPremium = false
        var plan: PremiumPlan?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard premiumProductIds.contains(transaction.productID),
                      transaction.revocationDate == nil else { continue }

                hasPremium = true
                // Ömür boyu satın alım, aboneliğin önüne geçer.
                if transaction.productID == lifetimeProductId {
                    plan = .lifetime
                } else if plan == nil {
                    plan = .monthly
                }
            } catch {
                // Hatalı/Onaysız işlem
            }
        }

        self.isPremium = hasPremium
        self.activePlan = plan
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        try? await AppStore.sync()
        await checkPremiumStatus()
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
