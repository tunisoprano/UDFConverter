import Foundation
import Combine

@MainActor
final class UsageLimitManager: ObservableObject {

    static let weeklyFreeLimit = 3

    @Published private(set) var usedThisWeek: Int
    @Published private(set) var nextResetDate: Date

    private let defaults: UserDefaults
    private let usedKey  = "usageLimit.usedThisWeek"
    private let resetKey = "usageLimit.nextResetDate"

    /// Bu hafta kalan hak.
    var remaining: Int { max(0, Self.weeklyFreeLimit - usedThisWeek) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedReset = defaults.object(forKey: resetKey) as? Date {
            self.usedThisWeek = defaults.integer(forKey: usedKey)
            self.nextResetDate = storedReset
        } else {
            self.usedThisWeek = 0
            self.nextResetDate = Self.nextMonday(after: Date())
        }
        resetIfNeeded()
    }

    /// Dönüştürme başlatılmadan önce çağrılır.
    func canConvert(isPremium: Bool) -> Bool {
        if isPremium { return true }
        resetIfNeeded()
        return usedThisWeek < Self.weeklyFreeLimit
    }

    /// Kullanıcı dönüştürmeyi başlattığı an (başarı beklenmeden) çağrılır.
    func recordConversionUsed() {
        resetIfNeeded()
        usedThisWeek += 1
        persist()
    }

    private func resetIfNeeded() {
        guard Date() >= nextResetDate else { return }
        usedThisWeek = 0
        nextResetDate = Self.nextMonday(after: Date())
        persist()
    }

    private func persist() {
        defaults.set(usedThisWeek, forKey: usedKey)
        defaults.set(nextResetDate, forKey: resetKey)
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
}
