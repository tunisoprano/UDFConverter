import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.openURL) private var openURL

    @State private var showPaywall = false
    @State private var legalSheetContent: LegalSheetContent?

    // App Store Connect Apple ID: 6802319326
    private let reviewURL = URL(string: "https://apps.apple.com/app/id6802319326?action=write-review")!

    // TODO: Yayına almadan önce "support@example.com" yerine gerçek destek e-postanızı girin.
    private let supportEmail = "support@example.com"

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
                    Button { legalSheetContent = .privacyPolicy } label: {
                        SettingsRow(icon: "hand.raised", title: L(.privacyPolicy), isExternal: false)
                    }
                    Button { legalSheetContent = .termsOfUse } label: {
                        SettingsRow(icon: "doc.text", title: L(.termsOfUse), isExternal: false)
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
            .sheet(item: $legalSheetContent) { content in
                LegalPlaceholderView(content: content)
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

// MARK: - Legal placeholder sheet

private enum LegalSheetContent: String, Identifiable {
    case privacyPolicy
    case termsOfUse

    var id: String { rawValue }
}

private struct LegalPlaceholderView: View {
    let content: LegalSheetContent

    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch content {
        case .privacyPolicy: return localizationManager.string(.privacyPolicy)
        case .termsOfUse:    return localizationManager.string(.termsOfUse)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                IconBadge(systemName: "doc.text", diameter: 72)
                    .padding(.top, 24)

                Text(localizationManager.string(.comingSoonTitle))
                    .font(.title2.bold())

                Text(localizationManager.string(.comingSoonMessage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
