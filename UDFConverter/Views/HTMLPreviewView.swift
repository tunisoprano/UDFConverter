import SwiftUI

struct PreviewScreen: View {
    let pdfURL: URL
    let fileName: String
    
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            PDFKitView(url: pdfURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Kapat") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            handleExport()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(LinearGradient.brandPrimary, in: Circle())
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: [pdfURL])
                }
        }
        .tint(.brandPrimary)
    }
    
    private func handleExport() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if !storeManager.isPremium {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                AdManager.shared.showInterstitial(from: rootVC) {
                    showShareSheet = true
                }
                return
            }
        }
        #endif
        
        showShareSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
