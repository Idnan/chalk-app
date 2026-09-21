import AppKit

/// One per display. Handles mouse and key input, renders committed annotations from a cached layer,
/// and draws the live stroke plus presenter effects (laser, spotlight, fading ink, toasts) on top.
final class CanvasView: NSView, NSTextFieldDelegate {
    let store: AnnotationStore
    unowned let state: ToolState
    unowned let controller: OverlayController

    // Live input
    private var liveStroke: [CGPoint] = []
    private var dragStart: CGPoint?
    private var dragEnd: CGPoint?
    private var dragSquare = false
    private var dragFromCenter = false
    private var lastLiveBounds: CGRect = .zero
    private var mousePoint: CGPoint = .zero

    // Cache of committed annotations
    private var cache: CGLayer?
    private var cacheDirty = true

    // Effects
    private var laserTrail: [(point: CGPoint, time: TimeInterval)] = []
    private var animationTimer: Timer?
    private var toast: (text: String, until: TimeInterval)?

    // Text tool
    private var textField: NSTextField?
    private var textOrigin: CGPoint?

    init(store: AnnotationStore, state: ToolState, controller: OverlayController) {
        self.store = store
        self.state = state
        self.controller = controller
        super.init(frame: .zero)
        wantsLayer = true
        store.onChange = { [weak self] in
            self?.cacheDirty = true
            self?.needsDisplay = true
            self?.updateAnimation()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    private var cursor: NSCursor {
        if state.laser { return .arrow }
        switch state.tool {
        case .text: return .iBeam
        case .eraser: return .disappearingItem
        default: return .crosshair
        }
    }

    /// Called by the controller after any tool or mode change.
    func refresh() {
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
        updateAnimation()
        if !state.laser { NSCursor.unhide() }
    }

    func invalidateCache() {
        cacheDirty = true
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let now = Date().timeIntervalSinceReferenceDate

        switch state.whiteboard {
        case .none: break
        case .white: ctx.setFillColor(NSColor(white: 0.98, alpha: 1).cgColor); ctx.fill(bounds)
        case .black: ctx.setFillColor(NSColor(white: 0.09, alpha: 1).cgColor); ctx.fill(bounds)
        }

        if state.fadeInk {
            let fade = Prefs.fadeSeconds
            for a in store.items {
                let age = now - a.createdAt
                let alpha = age < fade ? 1 : max(0, 1 - (age - fade) / 1.0)
                Renderer.draw(a, in: ctx, alpha: alpha)
            }
        } else {
            if cacheDirty || cache == nil { rebuildCache(with: ctx) }
            if let cache { ctx.draw(cache, at: .zero) }
        }

        if let live = liveAnnotation() {
            Renderer.draw(live, in: ctx)
        }

        if state.spotlight {
            Renderer.drawSpotlight(in: ctx, bounds: bounds, center: mousePoint, radius: CGFloat(Prefs.spotlightRadius))
        }

        if state.laser {
            Renderer.drawLaser(in: ctx, trail: laserTrail, now: now, color: state.color)
        }

        if let toast {
            let remaining = toast.until - now
            Renderer.drawToast(in: ctx, bounds: bounds, text: toast.text, alpha: min(1, max(0, remaining / 0.3)))
        }
    }

    private func rebuildCache(with ctx: CGContext) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard let layer = CGLayer(ctx, size: bounds.size, auxiliaryInfo: nil), let lctx = layer.context else { return }
        for a in store.items { Renderer.draw(a, in: lctx) }
        cache = layer
        cacheDirty = false
    }

    private func liveAnnotation() -> Annotation? {
        switch state.tool {
        case .pen:
            guard !liveStroke.isEmpty else { return nil }
            return Annotation(kind: .stroke(liveStroke), color: state.color, width: state.width)
        case .highlighter:
            guard !liveStroke.isEmpty else { return nil }
            return Annotation(kind: .highlight(liveStroke), color: state.color, width: state.width)
        case .line, .arrow, .rectangle, .ellipse:
            guard let start = dragStart, let rawEnd = dragEnd else { return nil }
            var end = rawEnd
            var lineStart = start
            if state.tool == .line || state.tool == .arrow {
                if dragSquare { end = Geometry.constrainAngle(start: start, end: end) }
                if dragFromCenter { lineStart = CGPoint(x: 2 * start.x - end.x, y: 2 * start.y - end.y) }
            }
            let rect = Geometry.dragRect(start: start, end: end, square: dragSquare, fromCenter: dragFromCenter)
            let kind: Annotation.Kind = switch state.tool {
            case .line: .line(lineStart, end)
            case .arrow: .arrow(lineStart, end)
            case .rectangle: .rectangle(rect)
            default: .ellipse(rect)
            }
            return Annotation(kind: kind, color: state.color, width: state.width)
        case .text, .marker, .eraser:
            return nil
        }
    }

    private func invalidateLive() {
        let rect = liveAnnotation()?.boundingBox ?? .zero
        setNeedsDisplay(rect.union(lastLiveBounds).insetBy(dx: -40, dy: -40))
        lastLiveBounds = rect
    }

    // MARK: Mouse

    override func mouseEntered(with event: NSEvent) {
        guard state.mode == .draw, let window, !window.isKeyWindow, textField == nil else { return }
        window.makeKey()
        window.makeFirstResponder(self)
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        mousePoint = p
        if state.laser {
            laserTrail.append((p, Date().timeIntervalSinceReferenceDate))
            needsDisplay = true
        } else if state.spotlight {
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        mousePoint = p
        controller.activeCanvas = self
        if let window, !window.isKeyWindow { window.makeKey() }
        if textField != nil { commitText(); return }
        window?.makeFirstResponder(self)
        if state.laser { return }

        dragSquare = event.modifierFlags.contains(.shift)
        dragFromCenter = event.modifierFlags.contains(.option)

        switch state.tool {
        case .pen, .highlighter:
            liveStroke = [p]
            invalidateLive()
        case .line, .arrow, .rectangle, .ellipse:
            dragStart = p
            dragEnd = p
            invalidateLive()
        case .text:
            beginText(at: p)
        case .marker:
            state.markerCount += 1
            store.add(Annotation(kind: .marker(state.markerCount, p), color: state.color, width: state.width))
        case .eraser:
            store.erase(at: p, tolerance: 8)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        mousePoint = p
        if state.laser {
            laserTrail.append((p, Date().timeIntervalSinceReferenceDate))
            needsDisplay = true
            return
        }
        dragSquare = event.modifierFlags.contains(.shift)
        dragFromCenter = event.modifierFlags.contains(.option)
        switch state.tool {
        case .pen, .highlighter:
            if let last = liveStroke.last, hypot(last.x - p.x, last.y - p.y) < 1.5 { return }
            liveStroke.append(p)
            invalidateLive()
        case .line, .arrow, .rectangle, .ellipse:
            dragEnd = p
            invalidateLive()
        case .eraser:
            store.erase(at: p, tolerance: 8)
        case .text, .marker:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        if state.laser { return }
        if let live = liveAnnotation() {
            var keep = true
            if case .rectangle(let r) = live.kind, r.width < 2, r.height < 2 { keep = false }
            if case .ellipse(let r) = live.kind, r.width < 2, r.height < 2 { keep = false }
            if keep { store.add(live) }
        }
        liveStroke = []
        dragStart = nil
        dragEnd = nil
        lastLiveBounds = .zero
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard state.spotlight else { return }
        let r = Prefs.spotlightRadius - Double(event.scrollingDeltaY) * 2
        UserDefaults.standard.set(min(600, max(40, r)), forKey: Prefs.spotlightRadiusKey)
        needsDisplay = true
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        guard let action = KeyMap.shared.action(for: event) else { return }
        if action == .laser {
            if !event.isARepeat { controller.setLaser(true) }
            return
        }
        if event.isARepeat && !action.allowsRepeat { return }
        controller.perform(action)
    }

    override func keyUp(with event: NSEvent) {
        if KeyMap.shared.action(for: event) == .laser { controller.setLaser(false) }
    }

    override func flagsChanged(with event: NSEvent) {
        // Update Shift/Option constraints mid-drag without waiting for the next mouse move.
        guard dragStart != nil || !liveStroke.isEmpty else { return }
        dragSquare = event.modifierFlags.contains(.shift)
        dragFromCenter = event.modifierFlags.contains(.option)
        invalidateLive()
    }

    // MARK: Laser and animation

    func setLaser(_ on: Bool) {
        if on {
            laserTrail = [(mousePoint, Date().timeIntervalSinceReferenceDate)]
            if window?.isKeyWindow == true { NSCursor.hide() }
        } else {
            laserTrail = []
            NSCursor.unhide()
        }
        refresh()
    }

    private var needsAnimation: Bool {
        state.laser || toast != nil || (state.fadeInk && !store.items.isEmpty)
    }

    private func updateAnimation() {
        if needsAnimation {
            guard animationTimer == nil else { return }
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func tick() {
        let now = Date().timeIntervalSinceReferenceDate
        if state.laser {
            laserTrail.removeAll { now - $0.time > 0.5 }
        }
        if state.fadeInk {
            store.expire(olderThan: Prefs.fadeSeconds + 1.0, now: now)
        }
        if let toast, toast.until < now { self.toast = nil }
        needsDisplay = true
        updateAnimation()
    }

    func showToast(_ text: String, seconds: TimeInterval = 1.4) {
        toast = (text, Date().timeIntervalSinceReferenceDate + seconds)
        needsDisplay = true
        updateAnimation()
    }

    // MARK: Text tool

    private func beginText(at p: CGPoint) {
        let fontSize = 10 + state.width * 3
        let height = ceil(fontSize * 1.5)
        let field = NSTextField(frame: NSRect(x: p.x, y: p.y - height, width: max(200, bounds.maxX - p.x - 20), height: height))
        field.font = .systemFont(ofSize: fontSize, weight: .semibold)
        field.textColor = state.color.nsColor
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderString = "Type, then Return"
        field.delegate = self
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        addSubview(field)
        textField = field
        textOrigin = p
        window?.makeFirstResponder(field)
    }

    private func commitText() {
        guard let field = textField, let origin = textOrigin else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            store.add(Annotation(kind: .text(text, origin), color: state.color, width: state.width))
        }
        endText()
    }

    private func endText() {
        textField?.removeFromSuperview()
        textField = nil
        textOrigin = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitText(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            endText(); return true
        default:
            return false
        }
    }
}
