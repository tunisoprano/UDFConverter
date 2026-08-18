import SwiftUI

struct LimitReachedView: View {
    let nextResetDate: Date

    @EnvironmentObject var usageLimitManager: UsageLimitManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingAd = false
    @State private var rewardEarned = false
    @State private var watchAdTapTrigger = false

    #if os(iOS)
    @ObservedObject private var adManager = AdManager.shared
    #endif

    private var resetDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE"
        return formatter.string(from: nextResetDate)
    }

    var body: some View {
        ScrollView {
            content
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: rewardEarned) { old, new in new }
        .onAppear {
            #if os(iOS)
            if !adManager.isRewardedAdLoaded {
                adManager.loadRewardedAd()
            }
            #endif
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            IconBadge(
                systemName: rewardEarned ? "checkmark.circle.fill" : "hourglass",
                gradient: rewardEarned ? .brandPrimary : .brandAccent,
                diameter: 88
            )
            .padding(.top, 12)

            Text(rewardEarned ? "+1 Hak Kazandınız!" : "Haftalık Limit Doldu")
                .font(.system(.title2, design: .rounded, weight: .bold))

            if rewardEarned {
                Text("Bonus hakkınız hesabınıza tanımlandı. Hemen dönüştürmeye devam edebilirsiniz.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else {
                Text("Bu haftaki ücretsiz dönüştürme hakkınız bitti.\nHaklarınız **\(resetDateText)** tarihinde yenilenecek.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            #if os(iOS)
            if !rewardEarned && usageLimitManager.canWatchRewardedAd() {
                VStack(spacing: 8) {
                    Button {
                        watchAdTapTrigger.toggle()
                        watchAd()
                    } label: {
                        if isPresentingAd {
                            ProgressView().tint(.white)
                        } else {
                            Label("Reklam İzle, +1 Hak Kazan", systemImage: "play.rectangle.fill")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(gradient: .brandAccent))
                    .disabled(!adManager.isRewardedAdLoaded || isPresentingAd)
                    .sensoryFeedback(.impact(weight: .medium), trigger: watchAdTapTrigger)

                    Text("Bugün \(usageLimitManager.remainingRewardedAdsToday)/\(UsageLimitManager.dailyRewardedAdCap) reklam hakkınız kaldı")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
            } else if !rewardEarned {
                Text("Bugünkü reklam hakkınız da doldu, yarın tekrar deneyebilirsiniz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            #endif

            if rewardEarned {
                Button("Harika") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            } else {
                Button("Şimdi Değil") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 36)
    }

    #if os(iOS)
    private func watchAd() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        isPresentingAd = true
        adManager.showRewardedAd(from: rootVC) {
            usageLimitManager.grantBonusConversion()
            rewardEarned = true
        } onDismiss: {
            isPresentingAd = false
        }
    }
    #endif
}
