import Foundation
import ZIPFoundation

enum UDFParserError: LocalizedError {
    case notAZipFile
    case contentXMLNotFound
    case xmlParseFailure(String)

    var errorDescription: String? {
        switch self {
        case .notAZipFile:            return "Dosya geçerli bir UDF/ZIP arşivi değil."
        case .contentXMLNotFound:     return "Arşiv içinde content.xml bulunamadı."
        case .xmlParseFailure(let m): return "XML ayrıştırma hatası: \(m)"
        }
    }
}

final class UDFParser: NSObject {

    // MARK: - Public

    func parse(url: URL) throws -> UDFDocument {
        let data = try extractContentXML(from: url)
        return try parseXML(data)
    }

    // MARK: - ZIP

    private func extractContentXML(from url: URL) throws -> Data {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw UDFParserError.notAZipFile
        }
        guard let entry = archive["content.xml"] else {
            throw UDFParserError.contentXMLNotFound
        }
        var result = Data()
        _ = try archive.extract(entry) { chunk in result.append(chunk) }
        return result
    }

    // MARK: - State

    private var fullText         = ""
    private var paragraphs       = [UDFParagraph]()
    private var style            = UDFStyle.default
    private var insideContent    = false
    private var insideParagraph  = false
    private var currentAlignment = UDFParagraph.TextAlignment.left
    private var currentSpans     = [UDFSpan]()

    // paragraph layout attrs
    private var currentLeftIndent:      Double = 0
    private var currentFirstLineIndent: Double = 0
    private var currentRightIndent:     Double = 0
    private var currentSpaceAbove:      Double = 0
    private var currentSpaceBelow:      Double = 0
    private var currentLineSpacing:     Double = 0
    private var currentTabStops:        [Double] = []

    // MARK: - XML

    private func parseXML(_ data: Data) throws -> UDFDocument {
        fullText = ""; paragraphs = []; style = .default
        insideContent = false; insideParagraph = false
        currentSpans = []; resetParagraphLayout()

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        if !parser.parse(), let err = parser.parserError {
            throw UDFParserError.xmlParseFailure(err.localizedDescription)
        }
        return UDFDocument(fullText: fullText, paragraphs: paragraphs, style: style)
    }

    private func resetParagraphLayout() {
        currentLeftIndent = 0; currentFirstLineIndent = 0; currentRightIndent = 0
        currentSpaceAbove = 0; currentSpaceBelow = 0; currentLineSpacing = 0
        currentTabStops = []
    }
}

// MARK: - XMLParserDelegate

extension UDFParser: XMLParserDelegate {

    func parser(_ parser: XMLParser,
                didStartElement el: String,
                namespaceURI: String?,
                qualifiedName _: String?,
                attributes a: [String: String] = [:]) {

        switch el {

        case "content" where !insideParagraph:
            insideContent = true

        case "paragraph":
            insideParagraph = true; insideContent = false; currentSpans = []
            let rawAlign = Int(a["Alignment"] ?? "0") ?? 0
            currentAlignment = UDFParagraph.TextAlignment(rawValue: rawAlign) ?? .left
            currentLeftIndent      = Double(a["LeftIndent"]      ?? "0") ?? 0
            currentFirstLineIndent = Double(a["FirstLineIndent"] ?? "0") ?? 0
            currentRightIndent     = Double(a["RightIndent"]     ?? "0") ?? 0
            currentSpaceAbove      = Double(a["SpaceAbove"]      ?? "0") ?? 0
            currentSpaceBelow      = Double(a["SpaceBelow"]      ?? "0") ?? 0
            currentLineSpacing     = Double(a["LineSpacing"]     ?? "0") ?? 0
            // TabSet format: "123.0:type:leader 150.0:type:leader"
            if let ts = a["TabSet"] {
                currentTabStops = ts.components(separatedBy: .whitespaces)
                    .compactMap { part in
                        if let first = part.components(separatedBy: ":").first {
                            return Double(first)
                        }
                        return nil
                    }
            } else {
                currentTabStops = []
            }
            // Hanging indent: positive Hanging shifts text right, first line stays
            if let hang = Double(a["Hanging"] ?? "0"), hang > 0 {
                currentLeftIndent      += hang
                currentFirstLineIndent  = -hang
            }

        case "content" where insideParagraph:
            guard
                let startStr = a["startOffset"], let start = Int(startStr),
                let lenStr   = a["length"],      let len   = Int(lenStr),
                start >= 0, len > 0
            else { return }
            let nsText = fullText as NSString
            guard start + len <= nsText.length else { return }
            let slice = nsText.substring(with: NSRange(location: start, length: len))

            let bold      = boolAttr(a["bold"])
            let italic    = boolAttr(a["italic"])
            let underline = boolAttr(a["underline"])
            let fontSize  = Double(a["size"] ?? "")
            let fontFamily = a["family"]
            let color     = cssColor(from: a["foreground"])
            currentSpans.append(UDFSpan(text: slice, isBold: bold, isItalic: italic,
                                        isUnderline: underline, fontSize: fontSize,
                                        fontFamily: fontFamily, color: color))

        case "style" where !insideParagraph:
            let fam  = a["family"] ?? style.fontFamily
            let size = Double(a["size"] ?? "") ?? style.fontSize
            style = UDFStyle(fontFamily: fam, fontSize: size)

        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        guard insideContent, !insideParagraph,
              let text = String(data: data, encoding: .utf8) else { return }
        fullText = text; insideContent = false
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideContent, !insideParagraph { fullText += string }
    }

    func parser(_ parser: XMLParser,
                didEndElement el: String,
                namespaceURI: String?,
                qualifiedName _: String?) {
        if el == "paragraph" {
            paragraphs.append(UDFParagraph(
                alignment:       currentAlignment,
                spans:           currentSpans,
                leftIndent:      currentLeftIndent,
                firstLineIndent: currentFirstLineIndent,
                rightIndent:     currentRightIndent,
                spaceAbove:      currentSpaceAbove,
                spaceBelow:      currentSpaceBelow,
                lineSpacing:     currentLineSpacing,
                tabStops:        currentTabStops
            ))
            insideParagraph = false
            resetParagraphLayout()
        }
    }

    // MARK: - Helpers

    /// "true"/"1" → true, "false"/"0" → false, nil → false
    private func boolAttr(_ val: String?) -> Bool {
        guard let v = val else { return false }
        return v == "true" || v == "1"
    }

    /// Java ARGB int (e.g. -4194304 = 0xFFC00000) → "#RRGGBB"
    private func cssColor(from val: String?) -> String? {
        guard let s = val, let i = Int32(s) else { return nil }
        let rgb = UInt32(bitPattern: i) & 0x00FFFFFF
        // skip black (#000000) — that's the default
        if rgb == 0 { return nil }
        return String(format: "#%06X", rgb)
    }
}
