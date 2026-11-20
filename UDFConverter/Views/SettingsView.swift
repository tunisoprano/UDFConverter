import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.openURL) private var openURL

    @State private var showPaywall = false

    // App Store Connect Apple ID: 6802319326
    private let reviewURL = URL(string: "https://apps.apple.com/app/id6802319326?action=write-review")!

    private let privacyPolicyURL = URL(string: "https://tunisoprano.github.io/udf2pdf-privacy/")!
    private let termsOfUseURL = URL(string: "https://tunisoprano.github.io/udf2pdf-terms/")!

    private let supportEmail = "tunahansaridev@gmail.com"

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(version)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L(.languageSectionTitle)) {
                    Picker(L(.languageSectionTitle), selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(L(.appearanceSectionTitle)) {
                    Picker(L(.appearanceSectionTitle), selection: appearanceBinding) {
                        Text(L(.appearanceLight)).tag(AppearanceMode.light)
                        Text(L(.appearanceDark)).tag(AppearanceMode.dark)
                        Text(L(.appearanceSystem)).tag(AppearanceMode.system)
                    }
                    .pickerStyle(.segmented)
                }

                Section(L(.premiumSectionTitle)) {
                    if storeManager.isPremium {
                        HStack {
                            Text(L(.premiumActiveBadge))
                                .font(.subheadline.weight(.semibold))
                            if let plan = storeManager.activePlan {
                                Text("· \(L(plan == .lifetime ? .planLifetime : .planMonthly))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    } else {
                        Button {
                            purchasePremium()
                        } label: {
                            Text(L(.premiumUpgradeButton))
                                .foregroundStyle(Color.brandAccent)
                        }
                    }

                    Button {
                        restorePurchases()
                    } label: {
                        Text(L(.premiumRestoreButton))
                    }
                }

                Section(L(.legalSectionTitle)) {
                    Button { openURL(privacyPolicyURL) } label: {
                        SettingsRow(icon: "hand.raised", title: L(.privacyPolicy), isExternal: true)
                    }
                    Button { openURL(termsOfUseURL) } label: {
                        SettingsRow(icon: "doc.text", title: L(.termsOfUse), isExternal: true)
                    }
                    Button { openURL(reviewURL) } label: {
                        SettingsRow(icon: "star", title: L(.rateUs), isExternal: true)
                    }
                    Button { openSupportEmail() } label: {
                        SettingsRow(icon: "envelope", title: L(.contactSupport), isExternal: true)
                    }
                }

                Section {
                    VStack(spacing: 4) {
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tolgahan Sarı & Tunahan Sarı")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L(.settingsTitle))
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func L(_ key: L10nKey) -> String {
        localizationManager.string(key)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { localizationManager.language }, set: { localizationManager.setLanguage($0) })
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(get: { appearanceManager.mode }, set: { appearanceManager.setMode($0) })
    }

    // MARK: - Actions

    /// Mevcut PaywallView zaten StoreKit'e bağlı (Faz 3) — burada onu açıyoruz.
    private func purchasePremium() {
        showPaywall = true
    }

    private func restorePurchases() {
        Task { await storeManager.restorePurchases() }
    }

    private func openSupportEmail() {
        guard let url = URL(string: "mailto:\(supportEmail)") else { return }
        openURL(url)
    }
}

// MARK: - Settings row

private struct SettingsRow: View {
    let icon: String
    let title: String
    let isExternal: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: isExternal ? "arrow.up.forward" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
