import SwiftUI
import WebKit

// MARK: - WebView

struct HTMLPreviewView: UIViewRepresentable {
    let html: String
    let onWebViewReady: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = .white
        webView.isOpaque = true
        onWebViewReady(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Preview Screen

struct PreviewScreen: View {
    let html: String
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var isGeneratingPDF = false

    var body: some View {
        NavigationStack {
            HTMLPreviewView(html: html) { wv in
                webView = wv
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isGeneratingPDF {
                        ProgressView()
                    } else {
                        Button {
                            exportPDF()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - PDF Export

    private func exportPDF() {
        guard let webView else { return }
        isGeneratingPDF = true

        // Get full content height from the web view, then render as one continuous PDF.
        // The system's print renderer will handle pagination when the user prints/saves.
        let contentHeight = webView.scrollView.contentSize.height
        let a4Width: CGFloat = 595.2
        let fullRect = CGRect(x: 0, y: 0, width: a4Width, height: max(contentHeight, 841.8))

        let config = WKPDFConfiguration()
        config.rect = fullRect

        webView.createPDF(configuration: config) { result in
            DispatchQueue.main.async {
                isGeneratingPDF = false
                switch result {
                case .failure(let err):
                    print("PDF error: \(err)")
                case .success(let data):
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(fileName + ".pdf")
                    try? data.write(to: tmp)
                    pdfURL = tmp
                    showShareSheet = true
                }
            }
        }
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
