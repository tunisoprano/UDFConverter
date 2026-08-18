import Foundation
import StoreKit
import Combine

@MainActor
final class StoreManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseErrorMessage: String?
    
    // Değiştirmeyi unutmayın: Kendi uygulamanızın Product ID'sini buraya girin.
    let premiumProductId = "com.udfconverter.premium"
    
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
                        await self?.updatePremiumStatus(transaction: transaction)
                        await transaction.finish()
                    }
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: [premiumProductId])
            self.products = storeProducts
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
            await updatePremiumStatus(transaction: transaction)
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func checkPremiumStatus() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == premiumProductId {
                    if transaction.revocationDate == nil {
                        hasPremium = true
                    }
                }
            } catch {
                // Hatalı/Onaysız işlem
            }
        }
        self.isPremium = hasPremium
    }
    
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        try? await AppStore.sync()
        await checkPremiumStatus()
    }
    
    @MainActor
    private func updatePremiumStatus(transaction: Transaction) async {
        if transaction.productID == premiumProductId {
            if transaction.revocationDate == nil {
                isPremium = true
            } else {
                isPremium = false
            }
        }
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
