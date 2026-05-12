import Foundation

struct HTMLGenerator {

    func generate(from document: UDFDocument) -> String {
        let body = document.paragraphs
            .map { paragraph(from: $0, style: document.style) }
            .joined(separator: "\n")

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
              white-space: pre-wrap;   /* preserves tab & newline characters */
              word-break: break-word;
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Paragraph

    private func paragraph(from p: UDFParagraph, style: UDFStyle) -> String {
        var css: [String] = []

        css.append("text-align:\(p.alignment.cssValue)")

        // Indents (pt)
        if p.leftIndent > 0 || p.firstLineIndent != 0 {
            let totalFirst = p.leftIndent + p.firstLineIndent
            css.append("padding-left:\(pt(p.leftIndent))")
            css.append("text-indent:\(pt(p.firstLineIndent))")
            _ = totalFirst // used via text-indent + padding-left
        }
        if p.rightIndent > 0 {
            css.append("padding-right:\(pt(p.rightIndent))")
        }

        // Vertical spacing
        if p.spaceAbove > 0 { css.append("margin-top:\(pt(p.spaceAbove))") }
        if p.spaceBelow > 0 { css.append("margin-bottom:\(pt(p.spaceBelow))") }
        if p.lineSpacing > 0 { css.append("line-height:\(pt(p.lineSpacing))") }

        // Tab stop via CSS tab-size (best-effort; CSS uses uniform repeat)
        if let ts = p.tabStop, ts > 0 {
            css.append("tab-size:\(pt(ts))")
            css.append("-moz-tab-size:\(pt(ts))")
        }

        let style = css.joined(separator: ";")

        if p.spans.isEmpty {
            return "<p style=\"\(style)\">&nbsp;</p>"
        }

        let inner = p.spans.map { span(from: $0) }.joined()
        return "<p style=\"\(style)\">\(inner)</p>"
    }

    // MARK: - Span

    private func span(from s: UDFSpan) -> String {
        // Escape HTML but preserve tabs (they live inside pre-wrap paragraphs)
        let escaped = s.text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        // \n inside a span → <br> is unnecessary with pre-wrap, but keep for safety
        // Tabs are preserved as-is by pre-wrap + tab-size

        var css: [String] = []
        if s.isBold      { css.append("font-weight:bold") }
        if s.isItalic    { css.append("font-style:italic") }
        if s.isUnderline { css.append("text-decoration:underline") }
        if let sz = s.fontSize  { css.append("font-size:\(pt(sz))") }
        if let ff = s.fontFamily, !ff.isEmpty { css.append("font-family:'\(ff)',serif") }
        if let c  = s.color     { css.append("color:\(c)") }

        if css.isEmpty { return escaped }
        return "<span style=\"\(css.joined(separator: ";"))\">\(escaped)</span>"
    }

    // MARK: - Helpers

    /// Format a point value as CSS pt string
    private func pt(_ v: Double) -> String {
        // Avoid fractional pt strings for clean CSS
        if v == v.rounded() { return "\(Int(v))pt" }
        return String(format: "%.1fpt", v)
    }
}
