import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchaseTapTrigger = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandAccent.opacity(0.10), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                IconBadge(systemName: "crown.fill", gradient: .brandAccent, diameter: 110)

                Text("Premium'a Geçin")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "nosign", title: "Reklamsız Deneyim", description: "PDF oluştururken araya giren veya alt kısımda duran tüm reklamları tamamen kaldırın.")
                    FeatureRow(icon: "infinity", title: "Sınırsız PDF Çıktısı", description: "Dilediğiniz kadar UDF dosyasını PDF'e saniyeler içinde dönüştürün.")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Abonelik Süresince Kesintisiz", description: "Aboneliğiniz aktif olduğu sürece tüm Premium özelliklere sınırsız erişin.")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                if storeManager.isPurchasing {
                    ProgressView("İşleminiz yapılıyor...")
                        .tint(.brandAccent)
                        .padding()
                } else if storeManager.products.isEmpty {
                    Text("Ürünler yüklenemedi. İnternet bağlantınızı kontrol edin.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .onAppear {
                            Task { await storeManager.fetchProducts() }
                        }
                } else {
                    ForEach(storeManager.products, id: \.id) { product in
                        Button {
                            purchaseTapTrigger.toggle()
                            Task {
                                do {
                                    try await storeManager.purchase(product)
                                    if storeManager.isPremium {
                                        dismiss()
                                    }
                                } catch {
                                    storeManager.purchaseErrorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            HStack {
                                Text("Abone Ol")
                                Spacer()
                                Text("\(product.displayPrice) / \(periodText(for: product))")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(gradient: .brandAccent))
                        .sensoryFeedback(.impact(weight: .medium), trigger: purchaseTapTrigger)
                        .padding(.horizontal)
                    }

                    // App Store'un otomatik yenilenen abonelikler için zorunlu kıldığı
                    // fiyat/süre/iptal bilgisi ve Kullanım Koşulları / Gizlilik Politikası bağlantıları.
                    VStack(spacing: 6) {
                        Text("Premium, seçilen ürünün fiyatı üzerinden aylık olarak faturalandırılır ve mevcut dönem bitmeden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir. Aboneliğinizi Ayarlar > [Apple ID'niz] > Abonelikler üzerinden istediğiniz zaman yönetebilir veya iptal edebilirsiniz.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            // TODO: Yayına almadan önce gerçek Kullanım Koşulları ve Gizlilik Politikası URL'leriyle değiştirin.
                            Link("Kullanım Koşulları", destination: URL(string: "https://example.com/terms")!)
                            Link("Gizlilik Politikası", destination: URL(string: "https://example.com/privacy")!)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                    }
                    .padding(.top, 4)
                }

                if let purchaseError = storeManager.purchaseErrorMessage {
                    Text(purchaseError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Daha Önce Satın Aldınız Mı? Geri Yükle") {
                    Task {
                        await storeManager.restorePurchases()
                        if storeManager.isPremium {
                            dismiss()
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.brandPrimary)
                .padding(.bottom, 24)
            }
        }
    }

    private func periodText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let count = period.value
        switch period.unit {
        case .day:   return count == 1 ? "gün" : "\(count) gün"
        case .week:  return count == 1 ? "hafta" : "\(count) hafta"
        case .month: return count == 1 ? "ay" : "\(count) ay"
        case .year:  return count == 1 ? "yıl" : "\(count) yıl"
        @unknown default: return ""
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            IconBadge(systemName: icon, diameter: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
