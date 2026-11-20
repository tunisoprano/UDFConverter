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
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw UDFParserError.notAZipFile
        }
        guard let entry = archive["content.xml"] else {
            throw UDFParserError.contentXMLNotFound
        }
        var result = Data()
        _ = try archive.extract(entry) { chunk in result.append(chunk) }
        return result
    }

    // MARK: - Mutable containers used while walking the tree

    /// Blokların biriktiği kap — belge kökü ya da bir tablo hücresi olabilir.
    private final class BlockContainer {
        var blocks: [UDFBlock] = []
    }

    private final class PartialTable {
        var columnSpans: [Double] = []
        var hasBorder = false
        var rows: [UDFTableRow] = []
        var leftIndent  = 0.0
        var rightIndent = 0.0
        var spaceAbove  = 0.0
        var spaceBelow  = 0.0
    }

    private final class PartialRow {
        var isHeader = false
        var cells: [UDFTableCell] = []
    }

    // MARK: - State

    private var fullText         = ""
    private var style            = UDFStyle.default
    private var insideContent    = false
    private var insideParagraph  = false
    private var currentAlignment = UDFParagraph.TextAlignment.left
    private var currentSpans     = [UDFSpan]()

    private var containerStack = [BlockContainer]()
    private var tableStack     = [PartialTable]()
    private var rowStack       = [PartialRow]()

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
        fullText = ""; style = .default
        insideContent = false; insideParagraph = false
        currentSpans = []; resetParagraphLayout()
        containerStack = [BlockContainer()]
        tableStack = []; rowStack = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        if !parser.parse(), let err = parser.parserError {
            throw UDFParserError.xmlParseFailure(err.localizedDescription)
        }
        return UDFDocument(fullText: fullText,
                           blocks: containerStack.first?.blocks ?? [],
                           style: style)
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

        case "table":
            let t = PartialTable()
            t.columnSpans = (a["columnSpans"] ?? "")
                .components(separatedBy: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            // border="borderNone" dışındaki her değer çizgili tablo demek
            t.hasBorder   = (a["border"] ?? "borderNone") != "borderNone"
            t.leftIndent  = Double(a["LeftIndent"]  ?? "0") ?? 0
            t.rightIndent = Double(a["RightIndent"] ?? "0") ?? 0
            t.spaceAbove  = Double(a["SpaceAbove"]  ?? "0") ?? 0
            t.spaceBelow  = Double(a["SpaceBelow"]  ?? "0") ?? 0
            tableStack.append(t)

        case "row":
            let r = PartialRow()
            r.isHeader = (a["rowType"] ?? "") == "headerRow"
            rowStack.append(r)

        case "cell":
            containerStack.append(BlockContainer())

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

        case "image" where insideParagraph:
            guard let b64 = a["imageData"],
                  let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
            else { return }
            currentSpans.append(UDFSpan(text: "", imageData: data))

        // `content` metnin kendisini, `field`/`space`/`tab` ise doldurulmuş alan,
        // boşluk ve sekme karakterlerini taşır — hepsi aynı offset şemasını kullanır.
        case "content", "field", "space", "tab":
            guard insideParagraph else { return }
            guard
                let startStr = a["startOffset"], let start = Int(startStr),
                let lenStr   = a["length"],      let len   = Int(lenStr),
                start >= 0, len > 0
            else { return }
            let nsText = fullText as NSString
            guard start + len <= nsText.length else { return }
            let slice = nsText.substring(with: NSRange(location: start, length: len))

            currentSpans.append(UDFSpan(text: slice,
                                        isBold: boolAttr(a["bold"]),
                                        isItalic: boolAttr(a["italic"]),
                                        isUnderline: boolAttr(a["underline"]),
                                        fontSize: Double(a["size"] ?? ""),
                                        fontFamily: a["family"],
                                        color: cssColor(from: a["foreground"])))

        case "style" where !insideParagraph:
            let fam  = a["family"] ?? style.fontFamily
            let size = Double(a["size"] ?? "") ?? style.fontSize
            style = UDFStyle(fontFamily: fam, fontSize: size)

        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        // Büyük CDATA blokları XMLParser tarafından birden fazla parçaya
        // bölünüp foundCDATA birden çok kez çağrılabiliyor — bu yüzden
        // üzerine yazmak yerine biriktiriyoruz (insideContent, ilgili
        // "content" elemanı didEndElement'te kapanana kadar açık kalır).
        guard insideContent, !insideParagraph,
              let text = String(data: data, encoding: .utf8) else { return }
        fullText += text
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideContent, !insideParagraph { fullText += string }
    }

    func parser(_ parser: XMLParser,
                didEndElement el: String,
                namespaceURI: String?,
                qualifiedName _: String?) {
        switch el {

        case "content":
            if insideContent, !insideParagraph { insideContent = false }

        case "paragraph":
            let p = UDFParagraph(
                alignment:       currentAlignment,
                spans:           currentSpans,
                leftIndent:      currentLeftIndent,
                firstLineIndent: currentFirstLineIndent,
                rightIndent:     currentRightIndent,
                spaceAbove:      currentSpaceAbove,
                spaceBelow:      currentSpaceBelow,
                lineSpacing:     currentLineSpacing,
                tabStops:        currentTabStops
            )
            containerStack.last?.blocks.append(.paragraph(p))
            insideParagraph = false
            currentSpans = []
            resetParagraphLayout()

        case "cell":
            guard containerStack.count > 1 else { return }
            let container = containerStack.removeLast()
            rowStack.last?.cells.append(UDFTableCell(blocks: container.blocks))

        case "row":
            guard let r = rowStack.popLast() else { return }
            tableStack.last?.rows.append(UDFTableRow(isHeader: r.isHeader, cells: r.cells))

        case "table":
            guard let t = tableStack.popLast() else { return }
            let table = UDFTable(columnSpans: t.columnSpans,
                                 hasBorder:   t.hasBorder,
                                 rows:        t.rows,
                                 leftIndent:  t.leftIndent,
                                 rightIndent: t.rightIndent,
                                 spaceAbove:  t.spaceAbove,
                                 spaceBelow:  t.spaceBelow)
            containerStack.last?.blocks.append(.table(table))

        default: break
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
