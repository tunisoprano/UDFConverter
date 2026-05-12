import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var showPicker    = false
    @State private var showPreview   = false
    @State private var generatedHTML = ""
    @State private var selectedName  = ""
    @State private var errorMessage: String?
    @State private var isProcessing  = false

    private let parser    = UDFParser()
    private let generator = HTMLGenerator()

    private static let udfType = UTType(filenameExtension: "udf") ?? .data

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("UDF Görüntüleyici")
                        .font(.largeTitle.bold())
                    Text("UYAP .udf belgelerini HTML olarak önizleyin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showPicker = true
                } label: {
                    Label("UDF Dosyası Seç", systemImage: "folder.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                if isProcessing {
                    ProgressView("İşleniyor…")
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 60)
            .navigationBarHidden(true)
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [Self.udfType],
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
            .sheet(isPresented: $showPreview) {
                PreviewScreen(html: generatedHTML, fileName: selectedName)
            }
        }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            processFile(url: url)
        }
    }

    private func processFile(url: URL) {
        isProcessing = true
        selectedName = url.deletingPathExtension().lastPathComponent

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let document = try parser.parse(url: url)
                let html = generator.generate(from: document)
                DispatchQueue.main.async {
                    isProcessing = false
                    generatedHTML = html
                    showPreview = true
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

#Preview {
    ContentView()
}
