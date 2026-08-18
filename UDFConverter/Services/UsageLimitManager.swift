import Foundation
import Combine

@MainActor
final class UsageLimitManager: ObservableObject {

    static let weeklyFreeLimit    = 3
    static let dailyRewardedAdCap = 3

    @Published private(set) var usedThisWeek: Int
    @Published private(set) var nextResetDate: Date

    @Published private(set) var bonusCredits: Int
    @Published private(set) var adsWatchedToday: Int
    @Published private(set) var dailyResetDate: Date

    private let defaults: UserDefaults
    private let usedKey           = "usageLimit.usedThisWeek"
    private let resetKey          = "usageLimit.nextResetDate"
    private let bonusKey          = "usageLimit.bonusCredits"
    private let adsWatchedKey     = "usageLimit.adsWatchedToday"
    private let dailyResetKey     = "usageLimit.dailyResetDate"

    /// Bu hafta kalan haktan gelen kısım (reklam bonusu hariç).
    var freeRemaining: Int { max(0, Self.weeklyFreeLimit - usedThisWeek) }

    /// Haftalık hak + reklamla kazanılmış bonus hakların toplamı.
    var remaining: Int { freeRemaining + bonusCredits }

    /// Bugün izlenebilecek reklam sayısı.
    var remainingRewardedAdsToday: Int { max(0, Self.dailyRewardedAdCap - adsWatchedToday) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedReset = defaults.object(forKey: resetKey) as? Date {
            self.usedThisWeek = defaults.integer(forKey: usedKey)
            self.nextResetDate = storedReset
        } else {
            self.usedThisWeek = 0
            self.nextResetDate = Self.nextMonday(after: Date())
        }
        if let storedDailyReset = defaults.object(forKey: dailyResetKey) as? Date {
            self.bonusCredits = defaults.integer(forKey: bonusKey)
            self.adsWatchedToday = defaults.integer(forKey: adsWatchedKey)
            self.dailyResetDate = storedDailyReset
        } else {
            self.bonusCredits = 0
            self.adsWatchedToday = 0
            self.dailyResetDate = Self.nextMidnight(after: Date())
        }
        resetIfNeeded()
        resetDailyIfNeeded()
    }

    /// Dönüştürme başlatılmadan önce çağrılır.
    func canConvert(isPremium: Bool) -> Bool {
        if isPremium { return true }
        resetIfNeeded()
        return usedThisWeek < Self.weeklyFreeLimit || bonusCredits > 0
    }

    /// Kullanıcı dönüştürmeyi başlattığı an (başarı beklenmeden) çağrılır.
    /// Önce haftalık ücretsiz hak, o dolduysa reklam bonusu harcanır.
    func recordConversionUsed() {
        resetIfNeeded()
        if usedThisWeek < Self.weeklyFreeLimit {
            usedThisWeek += 1
        } else if bonusCredits > 0 {
            bonusCredits -= 1
        }
        persist()
    }

    /// Limit dolduğunda kullanıcıya reklam izleme seçeneği gösterilip gösterilemeyeceği.
    func canWatchRewardedAd() -> Bool {
        resetDailyIfNeeded()
        return adsWatchedToday < Self.dailyRewardedAdCap
    }

    /// Bir ödüllü reklam tam izlendiğinde çağrılır: +1 bonus hak verir.
    /// Reklam SDK'sından bağımsızdır — sadece hak ekleme mantığını yönetir.
    func grantBonusConversion() {
        resetDailyIfNeeded()
        guard adsWatchedToday < Self.dailyRewardedAdCap else { return }
        adsWatchedToday += 1
        bonusCredits += 1
        persist()
    }

    private func resetIfNeeded() {
        guard Date() >= nextResetDate else { return }
        usedThisWeek = 0
        nextResetDate = Self.nextMonday(after: Date())
        persist()
    }

    private func resetDailyIfNeeded() {
        guard Date() >= dailyResetDate else { return }
        adsWatchedToday = 0
        dailyResetDate = Self.nextMidnight(after: Date())
        persist()
    }

    private func persist() {
        defaults.set(usedThisWeek, forKey: usedKey)
        defaults.set(nextResetDate, forKey: resetKey)
        defaults.set(bonusCredits, forKey: bonusKey)
        defaults.set(adsWatchedToday, forKey: adsWatchedKey)
        defaults.set(dailyResetDate, forKey: dailyResetKey)
    }

    /// Verilen tarihten sonraki ilk Pazartesi 00:00'ı (yerel takvim) döndürür.
    private static func nextMonday(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfToday) // 1 = Pazar, 2 = Pazartesi ...
        let daysUntilNextMonday = ((2 - weekday) + 7) % 7
        let offset = daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday
        return calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
    }

    /// Verilen tarihten sonraki ilk gece yarısını (yerel takvim) döndürür.
    private static func nextMidnight(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }
}
