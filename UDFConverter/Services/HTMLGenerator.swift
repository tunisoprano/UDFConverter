import Foundation

struct HTMLGenerator {

    func generate(from document: UDFDocument) -> String {
        let body = blocks(document.blocks, style: document.style)

        let ff = document.style.fontFamily
        let fs = document.style.fontSize

        return """
        <!DOCTYPE html>
        <html lang="tr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { box-sizing: border-box; }
            body {
              font-family: '\(ff)', 'Times New Roman', serif;
              font-size: \(fs)pt;
              margin: 1.5cm 2cm;
              line-height: 1.4;
              color: #000;
              background: #fff;
              -webkit-text-size-adjust: none;
            }
            p {
              margin: 0;
              padding: 0;
              word-break: break-word;
            }
            /* Tab-sütun hizalama için flex satır */
            .tab-row {
              display: flex;
              flex-direction: row;
              align-items: baseline;
              flex-wrap: nowrap;
            }
            .tab-cell {
              flex-shrink: 0;
              white-space: pre-wrap;
            }
            .tab-cell-last {
              flex: 1;
              white-space: pre-wrap;
            }
            table {
              border-collapse: collapse;
              width: 100%;
              table-layout: fixed;
            }
            td {
              vertical-align: top;
              padding: 1pt 3pt;
              word-break: break-word;
            }
            table.bordered, table.bordered td {
              border: 1px solid #000;
            }
            img.inline-img {
              vertical-align: middle;
              max-width: 100%;
            }
            @media print {
              body {
                margin: 0 !important;
              }
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Blocks

    private func blocks(_ blocks: [UDFBlock], style: UDFStyle) -> String {
        blocks.map { block in
            switch block {
            case .paragraph(let p): return paragraph(from: p, style: style)
            case .table(let t):     return table(from: t, style: style)
            }
        }
        .joined(separator: "\n")
    }

    // MARK: - Table

    private func table(from t: UDFTable, style: UDFStyle) -> String {
        // columnSpans oransal değerlerdir; yüzdeye çeviriyoruz.
        let total = t.columnSpans.reduce(0, +)
        let cols: String
        if total > 0 {
            cols = "<colgroup>" + t.columnSpans
                .map { "<col style=\"width:\(String(format: "%.2f", $0 / total * 100))%\">" }
                .joined() + "</colgroup>"
        } else {
            cols = ""
        }

        let rows = t.rows.map { row in
            let cells = row.cells.map { cell in
                let inner = blocks(cell.blocks, style: style)
                return "<td>\(inner.isEmpty ? "&nbsp;" : inner)</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()

        var css: [String] = []
        if t.leftIndent  > 0 { css.append("margin-left:\(pt(t.leftIndent))") }
        if t.rightIndent > 0 { css.append("margin-right:\(pt(t.rightIndent))") }
        if t.spaceAbove  > 0 { css.append("margin-top:\(pt(t.spaceAbove))") }
        if t.spaceBelow  > 0 { css.append("margin-bottom:\(pt(t.spaceBelow))") }

        let cls = t.hasBorder ? " class=\"bordered\"" : ""
        return "<table\(cls) style=\"\(css.joined(separator: ";"))\">\(cols)\(rows)</table>"
    }

    // MARK: - Paragraph

    private func paragraph(from p: UDFParagraph, style: UDFStyle) -> String {
        let fullText = p.spans.map { $0.text }.joined()
        let hasTab   = fullText.contains("\t")

        // Tab satırları için flex layout kullanıyoruz;
        // padding/text-indent flex hücrelerini kaydırdığı için ayrı yönetiyoruz.
        if hasTab, !p.tabStops.isEmpty {
            var css: [String] = []
            // Hizalamayı flex'te justify-content ile karşılıyoruz, text-align geçersiz
            if p.spaceAbove  > 0 { css.append("margin-top:\(pt(p.spaceAbove))") }
            if p.spaceBelow  > 0 { css.append("margin-bottom:\(pt(p.spaceBelow))") }
            if p.lineSpacing > 0 { css.append("line-height:\(pt(p.lineSpacing))") }
            if p.rightIndent > 0 { css.append("padding-right:\(pt(p.rightIndent))") }
            return tabParagraph(p: p, pStyle: css.joined(separator: ";"))
        }

        // Normal (tab'sız) paragraf
        var css: [String] = []
        css.append("text-align:\(p.alignment.cssValue)")
        if p.leftIndent      > 0  { css.append("padding-left:\(pt(p.leftIndent))") }
        if p.firstLineIndent != 0 { css.append("text-indent:\(pt(p.firstLineIndent))") }
        if p.rightIndent     > 0  { css.append("padding-right:\(pt(p.rightIndent))") }
        if p.spaceAbove      > 0  { css.append("margin-top:\(pt(p.spaceAbove))") }
        if p.spaceBelow      > 0  { css.append("margin-bottom:\(pt(p.spaceBelow))") }
        if p.lineSpacing     > 0  { css.append("line-height:\(pt(p.lineSpacing))") }
        let pStyle = css.joined(separator: ";")

        if p.spans.isEmpty {
            return "<p style=\"\(pStyle)\">&nbsp;</p>"
        }
        let inner = p.spans.map { span(from: $0) }.joined()
        return "<p style=\"\(pStyle); white-space:pre-wrap\">\(inner)</p>"
    }

    /// Tab içeren paragrafı flex sütunlarına bölerek hizalar
    private func tabParagraph(p: UDFParagraph, pStyle: String) -> String {
        // Tüm span'ları düz metin+biçim listesine çevir, tab'da böl
        // Önce span'ları tab karakterine göre parçalara ayır
        var segments: [[UDFSpan]] = [[]]   // her segment bir "sütun"

        for s in p.spans {
            if s.text.contains("\t") {
                let parts = s.text.components(separatedBy: "\t")
                for (i, part) in parts.enumerated() {
                    if !part.isEmpty {
                        let seg = UDFSpan(text: part, isBold: s.isBold, isItalic: s.isItalic,
                                         isUnderline: s.isUnderline, fontSize: s.fontSize,
                                         fontFamily: s.fontFamily, color: s.color)
                        segments[segments.count - 1].append(seg)
                    }
                    if i < parts.count - 1 {
                        segments.append([])   // yeni sütun
                    }
                }
            } else {
                segments[segments.count - 1].append(s)
            }
        }

        // Her sütunu HTML'e çevir
        var cells: [String] = []
        for (i, segs) in segments.enumerated() {
            let inner = segs.map { span(from: $0) }.joined()
            let content = inner.isEmpty ? "&nbsp;" : inner
            if i < segments.count - 1 {
                let currentPos = (i == 0) ? 0.0 : (i - 1 < p.tabStops.count ? p.tabStops[i - 1] : 0.0)
                let nextPos = i < p.tabStops.count ? p.tabStops[i] : (currentPos + 35.0)
                let width = nextPos - currentPos
                
                // Anahtar sütun: hesaplanan tab genişliği
                cells.append(
                    "<span class=\"tab-cell\" style=\"min-width:\(pt(width));max-width:\(pt(width))\">\(content)</span>"
                )
            } else {
                // Değer sütunu: geri kalan alan
                cells.append(
                    "<span class=\"tab-cell-last\" style=\"padding-left:0\">\(content)</span>"
                )
            }
        }

        let inner = cells.joined()
        return "<p class=\"tab-row\" style=\"\(pStyle)\">\(inner)</p>"
    }

    // MARK: - Span

    private func span(from s: UDFSpan) -> String {
        if let data = s.imageData {
            return "<img class=\"inline-img\" src=\"data:image/png;base64,\(data.base64EncodedString())\">"
        }

        let escaped = s.text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        var css: [String] = []
        if s.isBold       { css.append("font-weight:bold") }
        if s.isItalic     { css.append("font-style:italic") }
        if s.isUnderline  { css.append("text-decoration:underline") }
        if let sz = s.fontSize   { css.append("font-size:\(pt(sz))") }
        if let ff = s.fontFamily, !ff.isEmpty { css.append("font-family:'\(ff)',serif") }
        if let c  = s.color      { css.append("color:\(c)") }

        if css.isEmpty { return escaped }
        return "<span style=\"\(css.joined(separator: ";"))\">\(escaped)</span>"
    }

    // MARK: - Helpers

    private func pt(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))pt" : String(format: "%.1fpt", v)
    }
}
