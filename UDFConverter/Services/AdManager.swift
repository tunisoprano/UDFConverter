import Foundation
import Combine

#if os(iOS)
import GoogleMobileAds
import UIKit

final class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()

    @Published var isInterstitialLoaded = false
    @Published var isRewardedAdLoaded = false

    private var interstitial: InterstitialAd?
    private var rewardedAd: RewardedAd?

    // Değiştirmeyi unutmayın: Kendi uygulamanızın AdMob Geçiş (Interstitial) ID'sini girin.
    // Şimdilik Google'ın Test ID'si ile yapılandırıldı.
    private let interstitialID = "ca-app-pub-1674562447830288/6518038356"

    // Değiştirmeyi unutmayın: Yayına almadan önce kendi AdMob Ödüllü Reklam ID'nizi girin.
    // Şimdilik Google'ın resmi Ödüllü Reklam test ID'si ile yapılandırıldı.
    private let rewardedAdID = "ca-app-pub-3940256099942544/1712485313"

    private var interstitialDismissCompletion: (() -> Void)?
    private var rewardedDismissCompletion: (() -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Interstitial

    func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(with: interstitialID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Geçiş reklamı yüklenemedi: \(error.localizedDescription)")
                self?.isInterstitialLoaded = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isInterstitialLoaded = true
        }
    }

    func showInterstitial(from viewController: UIViewController, completion: @escaping () -> Void) {
        if let ad = interstitial {
            self.interstitialDismissCompletion = completion
            ad.present(from: viewController)
        } else {
            completion()
            loadInterstitial()
        }
    }

    // MARK: - Rewarded

    func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(with: rewardedAdID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Ödüllü reklam yüklenemedi: \(error.localizedDescription)")
                self?.isRewardedAdLoaded = false
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            self?.isRewardedAdLoaded = true
        }
    }

    /// `onReward` yalnızca kullanıcı reklamı sonuna kadar izlerse çağrılır.
    /// `onDismiss` reklam ekranı kapandığında (ödül kazanılsın kazanılmasın) her zaman çağrılır.
    func showRewardedAd(from viewController: UIViewController,
                         onReward: @escaping () -> Void,
                         onDismiss: @escaping () -> Void) {
        guard let ad = rewardedAd else {
            onDismiss()
            loadRewardedAd()
            return
        }
        self.rewardedDismissCompletion = onDismiss
        ad.present(from: viewController) {
            onReward()
        }
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad is RewardedAd {
            isRewardedAdLoaded = false
            rewardedDismissCompletion?()
            rewardedDismissCompletion = nil
            loadRewardedAd()
        } else {
            isInterstitialLoaded = false
            interstitialDismissCompletion?()
            interstitialDismissCompletion = nil
            loadInterstitial()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Reklam gösterilirken hata oluştu: \(error.localizedDescription)")
        if ad is RewardedAd {
            isRewardedAdLoaded = false
            rewardedDismissCompletion?()
            rewardedDismissCompletion = nil
            loadRewardedAd()
        } else {
            isInterstitialLoaded = false
            interstitialDismissCompletion?()
            interstitialDismissCompletion = nil
            loadInterstitial()
        }
    }
}
#endif
