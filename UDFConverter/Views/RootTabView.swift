import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var localizationManager: LocalizationManager

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label(localizationManager.string(.tabConvert), systemImage: "doc.badge.gearshape")
                }

            SettingsView()
                .tabItem {
                    Label(localizationManager.string(.tabSettings), systemImage: "gearshape")
                }
        }
        .tint(.brandPrimary)
        .preferredColorScheme(appearanceManager.mode.colorScheme)
    }
}
