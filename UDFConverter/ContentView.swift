import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var usageLimitManager: UsageLimitManager
    @EnvironmentObject var localizationManager: LocalizationManager

    @State private var showPicker    = false
    @State private var showPreview   = false
    @State private var showPaywall   = false
    @State private var showLimitReached = false
    @State private var generatedPDFURL: URL? = nil
    @State private var selectedName  = ""
    @State private var errorMessage: String?
    @State private var isProcessing  = false
    @State private var pickerTapTrigger = false

    private let parser    = UDFParser()
    private let generator = HTMLGenerator()

    private static let udfType = UTType(filenameExtension: "udf") ?? .item

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.brandPrimary.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    IconBadge(systemName: "doc.badge.gearshape", diameter: 104)
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text(localizationManager.string(.homeTitle))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(localizationManager.string(.homeSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 16) {
                        Button {
                            pickerTapTrigger.toggle()
                            showPicker = true
                        } label: {
                            Label("UDF Dosyası Seç", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.5 : 1)
                        .sensoryFeedback(.impact(weight: .medium), trigger: pickerTapTrigger)

                        if storeManager.isPremium {
                            PremiumChip()
                        } else {
                            UsageLimitCard(
                                freeRemaining: usageLimitManager.freeRemaining,
                                weeklyLimit: UsageLimitManager.weeklyFreeLimit,
                                bonusCredits: usageLimitManager.bonusCredits,
                                nextResetDate: usageLimitManager.nextResetDate
                            )
                        }
                    }
                    .padding(.horizontal, 32)

                    if isProcessing {
                        ProgressView("İşleniyor…")
                            .tint(.brandPrimary)
                            .transition(.opacity)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

                    Spacer()

                    // Sadece iOS'te ve Premium olmayanlara banner göster
                    #if os(iOS)
                    if !storeManager.isPremium {
                        BannerAdView()
                            .frame(width: 320, height: 50)
                    }
                    #endif
                }
                .padding(.top, 32)
                .animation(.easeInOut(duration: 0.25), value: isProcessing)
                .animation(.easeInOut(duration: 0.25), value: errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !storeManager.isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            Image(systemName: "crown.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(LinearGradient.brandAccent, in: Circle())
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [Self.udfType],
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
            .sheet(isPresented: $showPreview) {
                if let url = generatedPDFURL {
                    PreviewScreen(pdfURL: url, fileName: selectedName)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showLimitReached) {
                LimitReachedView(nextResetDate: usageLimitManager.nextResetDate)
            }
            .sensoryFeedback(.warning, trigger: showLimitReached) { old, new in new }
        }
        .tint(.brandPrimary)
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            guard usageLimitManager.canConvert(isPremium: storeManager.isPremium) else {
                showLimitReached = true
                return
            }
            usageLimitManager.recordConversionUsed()
            processFile(url: url)
        }
    }

    private func processFile(url: URL) {
        isProcessing = true
        selectedName = url.deletingPathExtension().lastPathComponent

        let accessing = url.startAccessingSecurityScopedResource()

        DispatchQueue.global(qos: .userInitiated).async {
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let document = try parser.parse(url: url)
                let html = generator.generate(from: document)
                DispatchQueue.main.async {
                    PDFGenerator.shared.generatePDF(from: html, fileName: self.selectedName) { pdfURL in
                        self.isProcessing = false
                        if let pdfURL = pdfURL {
                            self.generatedPDFURL = pdfURL
                            self.showPreview = true
                        } else {
                            self.errorMessage = "PDF dönüştürme işlemi başarısız oldu."
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Usage limit card

private struct UsageLimitCard: View {
    let freeRemaining: Int
    let weeklyLimit: Int
    let bonusCredits: Int
    let nextResetDate: Date

    private var totalRemaining: Int { freeRemaining + bonusCredits }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalRemaining) ücretsiz dönüştürme kaldı")
                    .font(.subheadline.weight(.semibold))
                if bonusCredits > 0 {
                    Text("\(freeRemaining) haftalık + \(bonusCredits) reklam bonusu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Self.weekdayFormatter.string(from: nextResetDate)) günü yenilenir")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<weeklyLimit, id: \.self) { i in
                    Circle()
                        .fill(i < freeRemaining ? Color.brandPrimary : Color.secondary.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
                if bonusCredits > 0 {
                    Text("+\(bonusCredits)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.brandAccent)
                        .padding(.leading, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Premium chip

private struct PremiumChip: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.brandPrimary)
            Text("Premium aktif — sınırsız dönüştürme")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandPrimary.opacity(0.1))
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
        .environmentObject(UsageLimitManager())
        .environmentObject(LocalizationManager())
}
