import Foundation
import WebKit
import UIKit

@MainActor
final class PDFGenerator: NSObject, WKNavigationDelegate {
    static let shared = PDFGenerator()
    
    private var webView: WKWebView?
    private var completion: ((URL?) -> Void)?
    private var fileName: String = "Document"
    
    private override init() {
        super.init()
    }
    
    func generatePDF(from html: String, fileName: String, completion: @escaping (URL?) -> Void) {
        // Prevent concurrent calls
        guard self.webView == nil else {
            completion(nil)
            return
        }
        
        self.completion = completion
        self.fileName = fileName
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595.2, height: 841.8))
        webView.navigationDelegate = self
        
        // Load the HTML content
        webView.loadHTMLString(html, baseURL: nil)
        
        // Keep a strong reference so it doesn't get deallocated before loading finishes
        self.webView = webView
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give it a tiny bit of time to render completely before taking a snapshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.createPDF(from: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    private func handleLoadFailure(_ error: Error) {
        print("PDF generation - HTML load failed: \(error)")
        self.completion?(nil)
        self.completion = nil
        self.webView = nil
    }
    
    private func createPDF(from webView: WKWebView) {
        let formatter = webView.viewPrintFormatter()
        let render = UIPrintPageRenderer()
        render.addPrintFormatter(formatter, startingAtPageAt: 0)
        
        // A4 Paper Size in points (595.2 x 841.8)
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        
        // 50pt margins (approx 1.76 cm)
        let printableRect = pageRect.insetBy(dx: 50, dy: 50)
        
        render.setValue(pageRect, forKey: "paperRect")
        render.setValue(printableRect, forKey: "printableRect")
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        
        for i in 0..<render.numberOfPages {
            UIGraphicsBeginPDFPage()
            render.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        
        UIGraphicsEndPDFContext()
        
        // Save to temporary directory
        let safeName = fileName.isEmpty ? "Belge" : fileName
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        do {
            try (pdfData as Data).write(to: tmp)
            self.completion?(tmp)
        } catch {
            print("PDF generation error: \(error)")
            self.completion?(nil)
        }
        
        // Cleanup
        self.webView = nil
        self.completion = nil
    }
}
