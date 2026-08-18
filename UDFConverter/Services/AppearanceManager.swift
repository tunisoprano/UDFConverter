import Foundation
import SwiftUI
import Combine

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {

    @Published private(set) var mode: AppearanceMode

    private let defaults: UserDefaults
    private let key = "app.appearanceMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: key), let stored = AppearanceMode(rawValue: raw) {
            self.mode = stored
        } else {
            self.mode = .system
        }
    }

    func setMode(_ mode: AppearanceMode) {
        self.mode = mode
        defaults.set(mode.rawValue, forKey: key)
    }
}
