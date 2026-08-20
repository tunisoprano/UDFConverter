import Foundation

struct UDFDocument {
    let fullText: String
    let blocks: [UDFBlock]
    let style: UDFStyle
}

/// Belge gövdesi paragraf ve tablo bloklarından oluşur; tablolar hücre içinde
/// yeniden tablo barındırabildiği için yapı özyinelemelidir.
enum UDFBlock {
    case paragraph(UDFParagraph)
    case table(UDFTable)
}

struct UDFTable {
    /// UDF'teki `columnSpans` değerleri — mutlak değil, birbirine göre orantılıdır.
    let columnSpans: [Double]
    let hasBorder:   Bool
    let rows:        [UDFTableRow]

    let leftIndent:  Double
    let rightIndent: Double
    let spaceAbove:  Double
    let spaceBelow:  Double
}

struct UDFTableRow {
    let isHeader: Bool
    let cells:    [UDFTableCell]
}

struct UDFTableCell {
    let blocks: [UDFBlock]
}

struct UDFParagraph {
    let alignment: TextAlignment
    let spans: [UDFSpan]

    // Paragraph-level layout
    let leftIndent:      Double   // pt
    let firstLineIndent: Double   // pt (positive = indent, negative = hanging)
    let rightIndent:     Double   // ptx
    let spaceAbove:      Double   // pt
    let spaceBelow:      Double   // pt
    let lineSpacing:     Double   // pt (0 = single)
    let tabStops:        [Double] // all tab-stop positions in pt

    enum TextAlignment: Int {
        case center  = 1
        case right   = 2
        case justify = 3
        case left    = 0

        var cssValue: String {
            switch self {
            case .center:  return "center"
            case .right:   return "right"
            case .justify: return "justify"
            case .left:    return "left"
            }
        }
    }
}

struct UDFSpan {
    let text:       String
    let isBold:     Bool
    let isItalic:   Bool
    let isUnderline:Bool
    let fontSize:   Double?   // nil → inherit from style
    let fontFamily: String?   // nil → inherit
    let color:      String?   // CSS hex string, nil → inherit
    /// Satır içi gömülü görsel (PNG). Doluysa `text` yok sayılır.
    let imageData:  Data?

    init(text: String,
         isBold: Bool = false,
         isItalic: Bool = false,
         isUnderline: Bool = false,
         fontSize: Double? = nil,
         fontFamily: String? = nil,
         color: String? = nil,
         imageData: Data? = nil) {
        self.text        = text
        self.isBold      = isBold
        self.isItalic    = isItalic
        self.isUnderline = isUnderline
        self.fontSize    = fontSize
        self.fontFamily  = fontFamily
        self.color       = color
        self.imageData   = imageData
    }
}

struct UDFStyle {
    let fontFamily: String
    let fontSize:   Double

    static let `default` = UDFStyle(fontFamily: "Times New Roman", fontSize: 12)
}
