import SwiftUI

struct PreviewScreen: View {
    let pdfURL: URL
    let document: UDFDocument
    let fileName: String

    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var shareItem: ShareItem?
    @State private var showPaywall = false
    @State private var exportError: String?

    private let docxGenerator = DOCXGenerator()

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
                        Menu {
                            Button {
                                exportPDF()
                            } label: {
                                Label("PDF olarak paylaş", systemImage: "doc.richtext")
                            }

                            Button {
                                exportDOCX()
                            } label: {
                                Label(
                                    storeManager.isPremium
                                        ? "Word olarak paylaş (.docx)"
                                        : "Word olarak paylaş (.docx) — Premium",
                                    systemImage: storeManager.isPremium ? "doc.text" : "lock.fill"
                                )
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(LinearGradient.brandPrimary, in: Circle())
                        }
                    }
                }
                .sheet(item: $shareItem) { item in
                    ShareSheet(items: [item.url])
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
                .alert("Dışa aktarma başarısız",
                       isPresented: Binding(get: { exportError != nil },
                                            set: { if !$0 { exportError = nil } })) {
                    Button("Tamam", role: .cancel) { exportError = nil }
                } message: {
                    Text(exportError ?? "")
                }
        }
        .tint(.brandPrimary)
    }

    // MARK: - Export

    private func exportPDF() {
        presentShare(for: pdfURL)
    }

    private func exportDOCX() {
        guard storeManager.isPremium else {
            showPaywall = true
            return
        }
        do {
            let url = try docxGenerator.generate(from: document, fileName: fileName)
            presentShare(for: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func presentShare(for url: URL) {
        shareItem = ShareItem(url: url)
    }
}

/// Paylaşılacak dosyayı `sheet(item:)` ile eşleştirebilmek için sarmalayıcı.
private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
