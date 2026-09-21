import AppKit

/// A color the model can hold without depending on AppKit in tests.
struct RGBA: Equatable, Hashable, Codable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat = 1

    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var cgColor: CGColor { nsColor.cgColor }
    func with(alpha: CGFloat) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

enum Palette {
    static let colors: [RGBA] = [
        RGBA(r: 0.96, g: 0.20, b: 0.20),   // 1 red
        RGBA(r: 1.00, g: 0.55, b: 0.10),   // 2 orange
        RGBA(r: 1.00, g: 0.85, b: 0.15),   // 3 yellow
        RGBA(r: 0.20, g: 0.80, b: 0.35),   // 4 green
        RGBA(r: 0.20, g: 0.50, b: 1.00),   // 5 blue
        RGBA(r: 0.60, g: 0.35, b: 0.95),   // 6 purple
        RGBA(r: 1.00, g: 0.40, b: 0.75),   // 7 pink
        RGBA(r: 0.05, g: 0.05, b: 0.05),   // 8 black
        RGBA(r: 1.00, g: 1.00, b: 1.00),   // 9 white
    ]
    static let names = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Black", "White"]
}

enum Tool: String, CaseIterable {
    case pen, highlighter, line, arrow, rectangle, ellipse, text, marker, eraser

    var label: String {
        switch self {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .line: "Line"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .text: "Text"
        case .marker: "Step marker"
        case .eraser: "Eraser"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil"
        case .highlighter: "highlighter"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .marker: "1.circle"
        case .eraser: "eraser"
        }
    }
}

struct Annotation: Identifiable, Equatable {
    enum Kind: Equatable {
        case stroke([CGPoint])
        case highlight([CGPoint])
        case line(CGPoint, CGPoint)
        case arrow(CGPoint, CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        /// Text with its top-left corner at the point.
        case text(String, CGPoint)
        case marker(Int, CGPoint)
    }

    let id: UUID
    var kind: Kind
    var color: RGBA
    var width: CGFloat
    var createdAt: TimeInterval

    init(kind: Kind, color: RGBA, width: CGFloat, createdAt: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        self.id = UUID()
        self.kind = kind
        self.color = color
        self.width = width
        self.createdAt = createdAt
    }

    // MARK: Derived geometry

    var fontSize: CGFloat { 10 + width * 3 }
    var markerRadius: CGFloat { 10 + width * 1.5 }
    var highlighterWidth: CGFloat { width * 5 }

    /// The path used for drawing outlines and hit testing. Text and markers use `boundingBox` instead.
    var path: CGPath? {
        switch kind {
        case .stroke(let pts), .highlight(let pts):
            return Geometry.smoothPath(pts)
        case .line(let a, let b):
            let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); return p
        case .arrow(let a, let b):
            let p = CGMutablePath(); p.move(to: a); p.addLine(to: Geometry.arrowHead(from: a, to: b, width: width).base); return p
        case .rectangle(let r):
            return CGPath(rect: r, transform: nil)
        case .ellipse(let r):
            return CGPath(ellipseIn: r, transform: nil)
        case .text, .marker:
            return nil
        }
    }

    /// Loose bounding box used for invalidation.
    var boundingBox: CGRect {
        switch kind {
        case .text(let s, let p):
            let size = Geometry.textSize(s, fontSize: fontSize)
            return CGRect(x: p.x, y: p.y - size.height, width: size.width, height: size.height)
        case .marker(_, let p):
            return CGRect(x: p.x - markerRadius, y: p.y - markerRadius, width: markerRadius * 2, height: markerRadius * 2)
        case .arrow(let a, let b):
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
                .insetBy(dx: -width * 4, dy: -width * 4)
        case .highlight:
            return (path?.boundingBoxOfPath ?? .zero).insetBy(dx: -highlighterWidth, dy: -highlighterWidth)
        default:
            return (path?.boundingBoxOfPath ?? .zero).insetBy(dx: -width * 2, dy: -width * 2)
        }
    }

    /// True when `point` lies within `tolerance` of the annotation's ink.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        switch kind {
        case .text, .marker:
            return boundingBox.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .highlight:
            guard let path else { return false }
            return path.copy(strokingWithWidth: highlighterWidth + tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point)
        case .arrow(_, let b):
            guard let path else { return false }
            if path.copy(strokingWithWidth: width + tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point) { return true }
            return CGRect(x: b.x - width * 4, y: b.y - width * 4, width: width * 8, height: width * 8).contains(point)
        default:
            guard let path else { return false }
            return path.copy(strokingWithWidth: width + tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point)
        }
    }
}

enum Geometry {
    /// Quadratic curve through segment midpoints. Cheap and smooth enough for freehand ink.
    static func smoothPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = pts.first else { return path }
        if pts.count == 1 {
            path.move(to: first)
            path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
            return path
        }
        if pts.count == 2 {
            path.move(to: first); path.addLine(to: pts[1]); return path
        }
        path.move(to: first)
        for i in 1..<pts.count - 1 {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i])
        }
        path.addLine(to: pts[pts.count - 1])
        return path
    }

    struct ArrowHead { var tip: CGPoint; var base: CGPoint; var left: CGPoint; var right: CGPoint }

    static func arrowHead(from a: CGPoint, to b: CGPoint, width: CGFloat) -> ArrowHead {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let ux = dx / len, uy = dy / len
        let headLen = min(max(14, width * 4), len)
        let headHalf = headLen * 0.45
        let base = CGPoint(x: b.x - ux * headLen, y: b.y - uy * headLen)
        let px = -uy, py = ux
        return ArrowHead(
            tip: b,
            base: base,
            left: CGPoint(x: base.x + px * headHalf, y: base.y + py * headHalf),
            right: CGPoint(x: base.x - px * headHalf, y: base.y - py * headHalf)
        )
    }

    static func textAttributes(fontSize: CGFloat, color: NSColor) -> [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        return [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: color,
            .shadow: shadow,
        ]
    }

    static func textSize(_ s: String, fontSize: CGFloat) -> CGSize {
        let attrs = textAttributes(fontSize: fontSize, color: .black)
        let size = (s as NSString).size(withAttributes: attrs)
        return CGSize(width: ceil(size.width) + 4, height: ceil(size.height))
    }

    /// Snap a drag end point to 45° increments around `start`.
    static func constrainAngle(start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let len = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let step = CGFloat.pi / 4
        let snapped = (angle / step).rounded() * step
        return CGPoint(x: start.x + cos(snapped) * len, y: start.y + sin(snapped) * len)
    }

    /// Rectangle from a drag, honoring Shift (square) and Option (from center).
    static func dragRect(start: CGPoint, end: CGPoint, square: Bool, fromCenter: Bool) -> CGRect {
        var dx = end.x - start.x, dy = end.y - start.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        if fromCenter {
            return CGRect(x: start.x - dx, y: start.y - dy, width: dx * 2, height: dy * 2).standardized
        }
        return CGRect(x: start.x, y: start.y, width: dx, height: dy).standardized
    }
}
