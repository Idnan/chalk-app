import AppKit

/// Draws annotations into a Core Graphics context. Stateless so it can render both the cached layer and the live stroke.
enum Renderer {
    static func draw(_ a: Annotation, in ctx: CGContext, alpha: CGFloat = 1) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setAlpha(alpha)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let color = a.color.cgColor

        switch a.kind {
        case .stroke, .line, .rectangle, .ellipse:
            guard let path = a.path else { return }
            ctx.setStrokeColor(color)
            ctx.setLineWidth(a.width)
            ctx.addPath(path)
            ctx.strokePath()

        case .highlight:
            guard let path = a.path else { return }
            ctx.setStrokeColor(a.color.with(alpha: 0.35).cgColor)
            ctx.setLineWidth(a.highlighterWidth)
            ctx.addPath(path)
            ctx.strokePath()

        case .arrow(let from, let to):
            let head = Geometry.arrowHead(from: from, to: to, width: a.width)
            ctx.setStrokeColor(color)
            ctx.setFillColor(color)
            ctx.setLineWidth(a.width)
            ctx.move(to: from)
            ctx.addLine(to: head.base)
            ctx.strokePath()
            ctx.move(to: head.tip)
            ctx.addLine(to: head.left)
            ctx.addLine(to: head.right)
            ctx.closePath()
            ctx.fillPath()

        case .text(let string, let origin):
            let attrs = Geometry.textAttributes(fontSize: a.fontSize, color: a.color.nsColor.withAlphaComponent(alpha))
            let size = Geometry.textSize(string, fontSize: a.fontSize)
            withNSGraphics(ctx) {
                (string as NSString).draw(in: NSRect(x: origin.x + 2, y: origin.y - size.height, width: size.width, height: size.height), withAttributes: attrs)
            }

        case .marker(let number, let center):
            let r = a.markerRadius
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.setFillColor(color)
            ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.5).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            let textColor: NSColor = a.color.r + a.color.g + a.color.b > 2.4 ? .black : .white
            let font = NSFont.systemFont(ofSize: r * 1.1, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor.withAlphaComponent(alpha)]
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attrs)
            withNSGraphics(ctx) {
                label.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)
            }
        }
    }

    /// Runs AppKit string drawing against a CG context (needed when drawing into a cache layer).
    private static func withNSGraphics(_ ctx: CGContext, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Presenter effects

    static func drawSpotlight(in ctx: CGContext, bounds: CGRect, center: CGPoint, radius: CGFloat) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.62).cgColor)
        ctx.fillPath(using: .evenOdd)
    }

    static func drawLaser(in ctx: CGContext, trail: [(point: CGPoint, time: TimeInterval)], now: TimeInterval, color: RGBA) {
        guard let last = trail.last else { return }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        // Trail: newest segments are widest and most opaque.
        if trail.count > 1 {
            for i in 1..<trail.count {
                let age = now - trail[i].time
                let t = max(0, 1 - age / 0.45)
                guard t > 0 else { continue }
                ctx.setStrokeColor(color.with(alpha: 0.7 * t).cgColor)
                ctx.setLineWidth(2 + 8 * t)
                ctx.move(to: trail[i - 1].point)
                ctx.addLine(to: trail[i].point)
                ctx.strokePath()
            }
        }
        // Glow and dot.
        let p = last.point
        ctx.setShadow(offset: .zero, blur: 18, color: color.with(alpha: 0.9).cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
    }

    static func drawToast(in ctx: CGContext, bounds: CGRect, text: String, alpha: CGFloat) {
        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white.withAlphaComponent(alpha)]
        let size = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 14
        let rect = CGRect(x: bounds.midX - size.width / 2 - pad, y: bounds.minY + 80, width: size.width + pad * 2, height: size.height + 16)
        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.75 * alpha).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        withNSGraphics(ctx) {
            (text as NSString).draw(at: NSPoint(x: rect.minX + pad, y: rect.minY + 8), withAttributes: attrs)
        }
    }
}
