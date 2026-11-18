import SwiftUI
import UIKit

/// Values measured from the final computed H5 styles at 420 x 912.
/// Source: design-reference/computed-style.json and 本地联调/swipe.js.
enum H5Design {
    static let ink = Color(hex: 0x302b32)
    static let muted = Color(hex: 0x816e75)
    static let devil = Color(hex: 0xe99386)
    static let angel = Color(hex: 0x9bc8dc)
    static let cardRadius: CGFloat = 30
    static let cardInset: CGFloat = 26
    static let buddySize: CGFloat = 58
    static let buddyBaseScale: CGFloat = 1.15
    static let buddyCampScale: CGFloat = 0.32
    static let settling = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)
    static let background = LinearGradient(stops: [
        .init(color: Color(hex: 0xf5aaa7), location: 0),
        .init(color: Color(hex: 0xf8d1c4), location: 0.32),
        .init(color: Color(hex: 0xf6e5dc), location: 0.49),
        .init(color: Color(hex: 0xdcebf2), location: 0.67),
        .init(color: Color(hex: 0xb7d9eb), location: 1)
    ], startPoint: UnitPoint(x: 0, y: 0.37), endPoint: UnitPoint(x: 1, y: 0.63))
    static let card = LinearGradient(colors: [Color(hex: 0xfffdf9).opacity(0.93), Color(hex: 0xfff8f4).opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func titleSize(_ width: CGFloat) -> CGFloat { min(31, max(23, width * 0.065)) }
    static func titleHeight(_ text: String, width: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: titleSize(width), weight: .bold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = titleSize(width) * 1.35
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        paragraph.alignment = .center
        let r = (text as NSString).boundingRect(with: CGSize(width: width - 106, height: 10000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .kern: -0.8, .paragraphStyle: paragraph], context: nil)
        return ceil(r.height)
    }
    static func cardHeight(_ text: String, width: CGFloat, available: CGFloat) -> CGFloat {
        min(max(220, titleHeight(text, width: width) + 160), max(220, available - 20))
    }
    static func verticalTravel(area: CGFloat, current: CGFloat, next: CGFloat) -> CGFloat {
        max(min(area, max(340, area * 0.78)), (current + next) / 2 + 20)
    }
    static func verticalProgress(raw: CGFloat, travel: CGFloat) -> CGFloat { 1 - exp(-abs(raw) / (travel * 1.32)) }
    static func fade(_ value: CGFloat) -> CGFloat { let t = min(1, max(0, value)); return t * t * (3 - 2 * t) }
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct CSSCornerShape: Shape {
    var corners: [CGFloat] = [0.47, 0.48, 0.45, 0.46]
    func path(in r: CGRect) -> Path {
        var radii = corners.map { CGSize(width: r.width * $0, height: r.height * $0) }
        let factor = min(1, r.width / max(1, radii[0].width + radii[1].width), r.width / max(1, radii[2].width + radii[3].width), r.height / max(1, radii[0].height + radii[3].height), r.height / max(1, radii[1].height + radii[2].height))
        radii = radii.map { CGSize(width: $0.width * factor, height: $0.height * factor) }
        let a = radii[0], b = radii[1], c = radii[2], d = radii[3], k: CGFloat = 0.55228475
        var p = Path(); p.move(to: CGPoint(x: a.width, y: 0)); p.addLine(to: CGPoint(x: r.width - b.width, y: 0))
        p.addCurve(to: CGPoint(x: r.width, y: b.height), control1: CGPoint(x: r.width - b.width * (1-k), y: 0), control2: CGPoint(x: r.width, y: b.height * (1-k)))
        p.addLine(to: CGPoint(x: r.width, y: r.height - c.height)); p.addCurve(to: CGPoint(x: r.width-c.width, y: r.height), control1: CGPoint(x: r.width, y: r.height-c.height*(1-k)), control2: CGPoint(x: r.width-c.width*(1-k), y: r.height))
        p.addLine(to: CGPoint(x: d.width, y: r.height)); p.addCurve(to: CGPoint(x: 0, y: r.height-d.height), control1: CGPoint(x: d.width*(1-k), y: r.height), control2: CGPoint(x: 0, y: r.height-d.height*(1-k)))
        p.addLine(to: CGPoint(x: 0, y: a.height)); p.addCurve(to: CGPoint(x: a.width, y: 0), control1: CGPoint(x: 0, y: a.height*(1-k)), control2: CGPoint(x: a.width*(1-k), y: 0));p.closeSubpath();return p
    }
}
