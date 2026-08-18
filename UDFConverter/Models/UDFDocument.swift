import Foundation

struct UDFDocument {
    let fullText: String
    let paragraphs: [UDFParagraph]
    let style: UDFStyle
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
}

struct UDFStyle {
    let fontFamily: String
    let fontSize:   Double

    static let `default` = UDFStyle(fontFamily: "Times New Roman", fontSize: 12)
}
