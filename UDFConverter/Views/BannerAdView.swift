import SwiftUI

#if os(iOS)
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewControllerRepresentable {
    // Değiştirmeyi unutmayın: Kendi uygulamanızın AdMob Banner ID'sini girin.
    // Şimdilik Google'ın Test ID'si ile yapılandırıldı.
    private let bannerID = "ca-app-pub-1674562447830288/4653578334"
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = bannerID
        bannerView.rootViewController = viewController
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        viewController.view.addSubview(bannerView)
        
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor)
        ])
        
        bannerView.load(Request())
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#else
// Mac'te AdMob olmadığı için boş (görünmez) bir View döndürüyoruz
struct BannerAdView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
