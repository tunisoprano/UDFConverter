import Foundation
import ZIPFoundation

/// `UDFDocument` modelinden düzenlenebilir bir .docx (OOXML) paketi üretir.
///
/// PDF'ten dönüştürme yapmaz — `HTMLGenerator` ile aynı ayrıştırılmış modelden
/// beslenir, böylece biçim bilgisi (girinti, hizalama, tab durakları, span
/// biçimleri) kayıpsız aktarılır.
struct DOCXGenerator {

    enum DOCXGeneratorError: LocalizedError {
        case archiveCreationFailed

        var errorDescription: String? {
            switch self {
            case .archiveCreationFailed: return "Word belgesi oluşturulamadı."
            }
        }
    }

    /// Üretilen .docx dosyasının geçici dizindeki konumunu döndürür.
    func generate(from document: UDFDocument, fileName: String) throws -> URL {
        let safeName = fileName.isEmpty ? "Belge" : fileName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).docx")

        // Aynı isimde eski bir çıktı varsa üzerine yazabilmek için önce siliyoruz;
        // ZIPFoundation .create modu mevcut dosyaya eklemeye çalışır.
        try? FileManager.default.removeItem(at: url)

        // Görseller ayrı paket parçası olarak yazılır; önce toplayıp numaralandırıyoruz.
        var images: [Data] = []
        collectImages(in: document.blocks, into: &images)

        let archive = try Archive(url: url, accessMode: .create)

        try add(contentTypesXML(hasImages: !images.isEmpty), as: "[Content_Types].xml", to: archive)
        try add(packageRelsXML,    as: "_rels/.rels",                to: archive)
        try add(documentRelsXML(imageCount: images.count), as: "word/_rels/document.xml.rels", to: archive)
        try add(stylesXML(for: document.style), as: "word/styles.xml", to: archive)
        try add(documentXML(for: document),     as: "word/document.xml", to: archive)

        for (i, data) in images.enumerated() {
            try addBinary(data, as: "word/media/image\(i + 1).png", to: archive)
        }

        return url
    }

    private func collectImages(in blocks: [UDFBlock], into images: inout [Data]) {
        for block in blocks {
            switch block {
            case .paragraph(let p):
                for s in p.spans where s.imageData != nil {
                    images.append(s.imageData!)
                }
            case .table(let t):
                for row in t.rows {
                    for cell in row.cells { collectImages(in: cell.blocks, into: &images) }
                }
            }
        }
    }

    private func addBinary(_ data: Data, as path: String, to archive: Archive) throws {
        try archive.addEntry(with: path,
                             type: .file,
                             uncompressedSize: Int64(data.count),
                             compressionMethod: .deflate) { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    private func add(_ xml: String, as path: String, to archive: Archive) throws {
        let data = Data(xml.utf8)
        try archive.addEntry(with: path,
                             type: .file,
                             uncompressedSize: Int64(data.count),
                             compressionMethod: .deflate) { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    // MARK: - Package parts

    private func contentTypesXML(hasImages: Bool) -> String {
        let png = hasImages ? "<Default Extension=\"png\" ContentType=\"image/png\"/>" : ""
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        \(png)
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """
    }

    private var packageRelsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private func documentRelsXML(imageCount: Int) -> String {
        // rId1 stiller; görseller rId2'den itibaren numaralanır.
        let imageRels = (0..<imageCount).map { i in
            "<Relationship Id=\"rId\(i + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image\(i + 1).png\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        \(imageRels)
        </Relationships>
        """
    }

    /// Belge genelindeki varsayılan font ve punto.
    private func stylesXML(for style: UDFStyle) -> String {
        let font = escape(style.fontFamily)
        let size = halfPoints(style.fontSize)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:docDefaults>
        <w:rPrDefault><w:rPr>
        <w:rFonts w:ascii="\(font)" w:hAnsi="\(font)" w:cs="\(font)"/>
        <w:sz w:val="\(size)"/><w:szCs w:val="\(size)"/>
        </w:rPr></w:rPrDefault>
        <w:pPrDefault><w:pPr>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
        </w:pPr></w:pPrDefault>
        </w:docDefaults>
        </w:styles>
        """
    }

    private func documentXML(for document: UDFDocument) -> String {
        var imageIndex = 0
        let body = blocks(document.blocks, width: contentWidthTwips, imageIndex: &imageIndex)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" \
        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <w:body>\(body)\(sectionProperties)</w:body>
        </w:document>
        """
    }

    /// A4 genişliği eksi kenar boşlukları — tablo sütunlarını bu alana dağıtıyoruz.
    private var contentWidthTwips: Int { 11906 - 1134 - 1134 }

    // MARK: - Blocks

    private func blocks(_ blocks: [UDFBlock], width: Int, imageIndex: inout Int) -> String {
        var out = ""
        for block in blocks {
            switch block {
            case .paragraph(let p):
                out += paragraph(p, imageIndex: &imageIndex)
            case .table(let t):
                out += table(t, width: width, imageIndex: &imageIndex)
                // Word, art arda gelen iki tabloyu birleştirir; araya boş paragraf koyuyoruz.
                out += "<w:p/>"
            }
        }
        return out
    }

    // MARK: - Table

    private func table(_ t: UDFTable, width: Int, imageIndex: inout Int) -> String {
        let columnCount = max(t.rows.map { $0.cells.count }.max() ?? 0, 1)

        // Oransal columnSpans'i kullanılabilir genişliğe dağıt; yoksa eşit böl.
        var widths: [Int]
        let spans = t.columnSpans.count == columnCount ? t.columnSpans : []
        let total = spans.reduce(0, +)
        if !spans.isEmpty, total > 0 {
            widths = spans.map { Int((Double(width) * $0 / total).rounded()) }
        } else {
            widths = Array(repeating: width / columnCount, count: columnCount)
        }
        // Yuvarlama farkını son sütuna ekleyerek toplam genişliği koru.
        if let last = widths.indices.last {
            widths[last] += width - widths.reduce(0, +)
        }

        let borders = t.hasBorder
            ? """
              <w:tblBorders>\
              <w:top w:val="single" w:sz="4" w:color="000000"/>\
              <w:left w:val="single" w:sz="4" w:color="000000"/>\
              <w:bottom w:val="single" w:sz="4" w:color="000000"/>\
              <w:right w:val="single" w:sz="4" w:color="000000"/>\
              <w:insideH w:val="single" w:sz="4" w:color="000000"/>\
              <w:insideV w:val="single" w:sz="4" w:color="000000"/>\
              </w:tblBorders>
              """
            : "<w:tblBorders><w:top w:val=\"none\"/><w:left w:val=\"none\"/><w:bottom w:val=\"none\"/><w:right w:val=\"none\"/><w:insideH w:val=\"none\"/><w:insideV w:val=\"none\"/></w:tblBorders>"

        let indent = t.leftIndent > 0 ? "<w:tblInd w:w=\"\(twips(t.leftIndent))\" w:type=\"dxa\"/>" : ""
        let grid = "<w:tblGrid>" + widths.map { "<w:gridCol w:w=\"\($0)\"/>" }.joined() + "</w:tblGrid>"

        var rowsXML = ""
        for row in t.rows {
            var cellsXML = ""
            for (i, cell) in row.cells.enumerated() {
                let w = i < widths.count ? widths[i] : widths.last ?? 0
                var inner = blocks(cell.blocks, width: w, imageIndex: &imageIndex)
                // OOXML kuralı: her hücre en az bir paragrafla bitmeli.
                if inner.isEmpty || inner.hasSuffix("</w:tbl>") { inner += "<w:p/>" }
                cellsXML += """
                <w:tc><w:tcPr><w:tcW w:w="\(w)" w:type="dxa"/></w:tcPr>\(inner)</w:tc>
                """
            }
            let header = row.isHeader ? "<w:trPr><w:tblHeader/></w:trPr>" : ""
            rowsXML += "<w:tr>\(header)\(cellsXML)</w:tr>"
        }

        return """
        <w:tbl><w:tblPr><w:tblW w:w="\(width)" w:type="dxa"/>\(indent)\(borders)\
        <w:tblLayout w:type="fixed"/></w:tblPr>\(grid)\(rowsXML)</w:tbl>
        """
    }

    /// A4 sayfa boyutu ve HTML çıktısıyla aynı kenar boşlukları (1.5cm / 2cm).
    private var sectionProperties: String {
        """
        <w:sectPr>
        <w:pgSz w:w="11906" w:h="16838"/>
        <w:pgMar w:top="850" w:right="1134" w:bottom="850" w:left="1134" w:header="0" w:footer="0" w:gutter="0"/>
        </w:sectPr>
        """
    }

    // MARK: - Paragraph

    private func paragraph(_ p: UDFParagraph, imageIndex: inout Int) -> String {
        var runs = ""
        for span in p.spans {
            if let data = span.imageData {
                imageIndex += 1
                runs += imageRun(data, index: imageIndex)
            } else {
                runs += run(from: span)
            }
        }
        return "<w:p>\(paragraphProperties(p))\(runs)</w:p>"
    }

    // MARK: - Inline image

    /// PNG'yi satır içi çizim (`w:drawing`) olarak gömer.
    private func imageRun(_ data: Data, index: Int) -> String {
        let (pxW, pxH) = pngSize(data) ?? (16, 16)
        // EMU: 96 DPI varsayımıyla 1 piksel = 9525 EMU
        let cx = pxW * 9525
        let cy = pxH * 9525
        let relId = "rId\(index + 1)"   // rId1 stiller, görseller rId2'den başlar
        return """
        <w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">\
        <wp:extent cx="\(cx)" cy="\(cy)"/><wp:docPr id="\(index)" name="Gorsel \(index)"/>\
        <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">\
        <pic:pic><pic:nvPicPr><pic:cNvPr id="\(index)" name="Gorsel \(index)"/><pic:cNvPicPr/></pic:nvPicPr>\
        <pic:blipFill><a:blip r:embed="\(relId)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>\
        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>\
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>\
        </a:graphicData></a:graphic></wp:inline></w:drawing></w:r>
        """
    }

    /// PNG başlığındaki IHDR bloğundan genişlik/yükseklik okur.
    private func pngSize(_ data: Data) -> (Int, Int)? {
        guard data.count >= 24 else { return nil }
        let bytes = [UInt8](data)
        // 0..7 imza, 8..15 uzunluk + "IHDR", 16..19 genişlik, 20..23 yükseklik (big-endian)
        func int32(_ o: Int) -> Int {
            (Int(bytes[o]) << 24) | (Int(bytes[o+1]) << 16) | (Int(bytes[o+2]) << 8) | Int(bytes[o+3])
        }
        let w = int32(16), h = int32(20)
        guard w > 0, h > 0, w < 20000, h < 20000 else { return nil }
        return (w, h)
    }

    /// OOXML şeması `w:pPr` alt öğelerinin sırasını dayatır:
    /// tabs → spacing → ind → jc. Sıra bozulursa Word dosyayı açmayı reddeder.
    private func paragraphProperties(_ p: UDFParagraph) -> String {
        var parts: [String] = []

        if !p.tabStops.isEmpty {
            let stops = p.tabStops
                .map { "<w:tab w:val=\"left\" w:pos=\"\(twips($0))\"/>" }
                .joined()
            parts.append("<w:tabs>\(stops)</w:tabs>")
        }

        var spacing: [String] = []
        if p.spaceAbove > 0 { spacing.append("w:before=\"\(twips(p.spaceAbove))\"") }
        if p.spaceBelow > 0 { spacing.append("w:after=\"\(twips(p.spaceBelow))\"") }
        if p.lineSpacing > 0 {
            // "atLeast" kullanıyoruz: "exact" satır yüksekliği punto'dan küçük
            // kalırsa Word metni kırpıyor, bu da belgeyi bozuk gösteriyor.
            spacing.append("w:line=\"\(twips(p.lineSpacing))\" w:lineRule=\"atLeast\"")
        }
        if !spacing.isEmpty {
            parts.append("<w:spacing \(spacing.joined(separator: " "))/>")
        }

        var indent: [String] = []
        if p.leftIndent  > 0 { indent.append("w:left=\"\(twips(p.leftIndent))\"") }
        if p.rightIndent > 0 { indent.append("w:right=\"\(twips(p.rightIndent))\"") }
        if p.firstLineIndent > 0 {
            indent.append("w:firstLine=\"\(twips(p.firstLineIndent))\"")
        } else if p.firstLineIndent < 0 {
            // Negatif ilk satır girintisi Word'de "hanging" olarak, pozitif değerle ifade edilir.
            indent.append("w:hanging=\"\(twips(-p.firstLineIndent))\"")
        }
        if !indent.isEmpty {
            parts.append("<w:ind \(indent.joined(separator: " "))/>")
        }

        parts.append("<w:jc w:val=\"\(alignmentValue(p.alignment))\"/>")

        return "<w:pPr>\(parts.joined())</w:pPr>"
    }

    private func alignmentValue(_ a: UDFParagraph.TextAlignment) -> String {
        switch a {
        case .left:    return "left"
        case .center:  return "center"
        case .right:   return "right"
        case .justify: return "both"
        }
    }

    // MARK: - Run

    private func run(from s: UDFSpan) -> String {
        let content = runContent(s.text)
        guard !content.isEmpty else { return "" }
        return "<w:r>\(runProperties(s))\(content)</w:r>"
    }

    /// Tab ve satır sonu, `w:t` içinde düz karakter olarak taşınamaz;
    /// kendi öğelerine ayrılmaları gerekir.
    private func runContent(_ text: String) -> String {
        var out = ""
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            out += "<w:t xml:space=\"preserve\">\(escape(buffer))</w:t>"
            buffer = ""
        }

        for ch in text {
            switch ch {
            case "\t":
                flush(); out += "<w:tab/>"
            case "\n":
                flush(); out += "<w:br/>"
            case "\r":
                continue
            default:
                buffer.append(ch)
            }
        }
        flush()
        return out
    }

    /// `w:rPr` de sıra bağımlıdır: rFonts → b → i → color → sz/szCs → u.
    private func runProperties(_ s: UDFSpan) -> String {
        var parts: [String] = []

        if let family = s.fontFamily, !family.isEmpty {
            let f = escape(family)
            parts.append("<w:rFonts w:ascii=\"\(f)\" w:hAnsi=\"\(f)\" w:cs=\"\(f)\"/>")
        }
        if s.isBold   { parts.append("<w:b/><w:bCs/>") }
        if s.isItalic { parts.append("<w:i/><w:iCs/>") }
        if let color = s.color {
            parts.append("<w:color w:val=\"\(color.replacingOccurrences(of: "#", with: ""))\"/>")
        }
        if let size = s.fontSize {
            let hp = halfPoints(size)
            parts.append("<w:sz w:val=\"\(hp)\"/><w:szCs w:val=\"\(hp)\"/>")
        }
        if s.isUnderline { parts.append("<w:u w:val=\"single\"/>") }

        guard !parts.isEmpty else { return "" }
        return "<w:rPr>\(parts.joined())</w:rPr>"
    }

    // MARK: - Helpers

    /// OOXML uzunlukları twip cinsindendir (1 pt = 20 twip).
    private func twips(_ points: Double) -> Int {
        Int((points * 20).rounded())
    }

    /// Punto değerleri yarım-punto cinsinden yazılır (12 pt → 24).
    private func halfPoints(_ points: Double) -> Int {
        max(1, Int((points * 2).rounded()))
    }

    private func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.unicodeScalars {
            switch ch {
            case "&":  out += "&amp;"
            case "<":  out += "&lt;"
            case ">":  out += "&gt;"
            case "\"": out += "&quot;"
            case "'":  out += "&apos;"
            default:
                // XML 1.0 kontrol karakterlerine izin vermez; sessizce atıyoruz.
                if ch.value >= 0x20 || ch == "\t" || ch == "\n" {
                    out.unicodeScalars.append(ch)
                }
            }
        }
        return out
    }
}
