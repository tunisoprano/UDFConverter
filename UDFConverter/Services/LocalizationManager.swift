import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}

enum L10nKey {
    case tabConvert
    case tabSettings
    case homeTitle
    case homeSubtitle
    case settingsTitle
    case languageSectionTitle
    case appearanceSectionTitle
    case appearanceLight
    case appearanceDark
    case appearanceSystem
    case premiumSectionTitle
    case premiumUpgradeButton
    case premiumRestoreButton
    case premiumActiveBadge
    case legalSectionTitle
    case privacyPolicy
    case termsOfUse
    case rateUs
    case contactSupport
    case comingSoonTitle
    case comingSoonMessage
}

/// Sistem dilinden bağımsız, uygulama içi anlık dil değişimi sağlayan basit yerelleştirme yöneticisi.
/// Şu an sadece Ayarlar sekmesini kapsıyor; yeni ekranlar aynı `L10nKey`/`string(_:)` deseniyle eklenebilir.
@MainActor
final class LocalizationManager: ObservableObject {

    @Published private(set) var language: AppLanguage

    private let defaults: UserDefaults
    private let key = "app.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: key), let stored = AppLanguage(rawValue: raw) {
            self.language = stored
        } else {
            self.language = .turkish
        }
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        defaults.set(language.rawValue, forKey: key)
    }

    func string(_ key: L10nKey) -> String {
        translations[key]?[language] ?? ""
    }

    private let translations: [L10nKey: [AppLanguage: String]] = [
        .tabConvert: [.turkish: "Dönüştür", .english: "Convert"],
        .tabSettings: [.turkish: "Ayarlar", .english: "Settings"],
        .homeTitle: [.turkish: "UDF → PDF", .english: "UDF → PDF"],
        .homeSubtitle: [.turkish: "UYAP .udf belgelerini PDF'e dönüştürün veya görüntüleyin", .english: "Convert or view your UYAP .udf files to PDF"],
        .settingsTitle: [.turkish: "Ayarlar", .english: "Settings"],
        .languageSectionTitle: [.turkish: "Dil", .english: "Language"],
        .appearanceSectionTitle: [.turkish: "Görünüm", .english: "Appearance"],
        .appearanceLight: [.turkish: "Açık", .english: "Light"],
        .appearanceDark: [.turkish: "Koyu", .english: "Dark"],
        .appearanceSystem: [.turkish: "Sistem", .english: "System"],
        .premiumSectionTitle: [.turkish: "Premium", .english: "Premium"],
        .premiumUpgradeButton: [.turkish: "Premium'a Geç", .english: "Upgrade to Premium"],
        .premiumRestoreButton: [.turkish: "Satın Alımları Geri Yükle", .english: "Restore Purchases"],
        .premiumActiveBadge: [.turkish: "Premium Aktif", .english: "Premium Active"],
        .legalSectionTitle: [.turkish: "Yasal & Bilgi", .english: "Legal & Info"],
        .privacyPolicy: [.turkish: "Gizlilik Politikası", .english: "Privacy Policy"],
        .termsOfUse: [.turkish: "Kullanım Koşulları", .english: "Terms of Use"],
        .rateUs: [.turkish: "Bizi Değerlendirin", .english: "Rate Us"],
        .contactSupport: [.turkish: "Destek / İletişim", .english: "Support / Contact"],
        .comingSoonTitle: [.turkish: "Yakında", .english: "Coming Soon"],
        .comingSoonMessage: [.turkish: "Bu sayfa yakında eklenecek.", .english: "This page will be added soon."],
    ]
}
