import AppKit
import SwiftUI

/// Owns one overlay window per display plus the floating palette and cheat sheet, and applies mode changes.
@MainActor
final class OverlayController {
    unowned let state: ToolState
    private(set) var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var stores: [CGDirectDisplayID: AnnotationStore] = [:]
    /// The canvas that last received a click; undo, redo and delete target it.
    weak var activeCanvas: CanvasView?

    private var palette: FloatingPanel?
    private var paletteMovedByUser = false
    private var positioningPalette = false
    private var cheatSheet: FloatingPanel?
    private var observers: [Any] = []

    init(state: ToolState) {
        self.state = state
    }

    func start() {
        rebuildWindows()
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        })
    }

    var canvases: [CanvasView] { windows.values.map(\.canvas) }

    // MARK: Windows

    func rebuildWindows() {
        let screens = NSScreen.screens
        let liveIDs = Set(screens.map(\.displayID))
        for (id, window) in windows where !liveIDs.contains(id) {
            window.orderOut(nil)
            windows[id] = nil
        }
        for screen in screens {
            let id = screen.displayID
            if let window = windows[id] {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                    window.canvas.invalidateCache()
                }
            } else {
                let store = stores[id] ?? AnnotationStore()
                stores[id] = store
                let canvas = CanvasView(store: store, state: state, controller: self)
                windows[id] = OverlayWindow(screen: screen, canvas: canvas)
            }
        }
        apply(mode: state.mode)
    }

    func apply(mode: Mode) {
        state.mode = mode
        switch mode {
        case .off:
            hidePalette()
            hideCheatSheet()
            setLaser(false)
            state.spotlight = false
            for w in windows.values { w.orderOut(nil) }
            if Prefs.clearOnExit { clearAll() }
        case .draw:
            for w in windows.values {
                w.ignoresMouseEvents = false
                w.orderFrontRegardless()
            }
            let target = windowUnderMouse() ?? windows.values.first
            target?.makeKeyAndOrderFront(nil)
            if let target { target.makeFirstResponder(target.canvas) }
            if Prefs.showPalette { showPalette() }
        case .freeze:
            hidePalette()
            hideCheatSheet()
            setLaser(false)
            state.spotlight = false
            for w in windows.values {
                w.ignoresMouseEvents = true
                // Order out and back in so the panel gives up key status and typing returns to the app underneath.
                w.orderOut(nil)
                w.orderFrontRegardless()
            }
        }
        refreshAll()
    }

    func refreshAll() {
        canvases.forEach { $0.refresh() }
    }

    func windowUnderMouse() -> OverlayWindow? {
        let mouse = NSEvent.mouseLocation
        return windows.values.first { $0.frame.contains(mouse) }
    }

    func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    /// The canvas that editing commands act on.
    var currentCanvas: CanvasView? {
        activeCanvas ?? windowUnderMouse()?.canvas ?? windows.values.first?.canvas
    }

    func clearAll() {
        stores.values.forEach { $0.clear() }
        state.markerCount = 0
    }

    var hasAnnotations: Bool { stores.values.contains { !$0.isEmpty } }

    // MARK: Laser

    func setLaser(_ on: Bool) {
        guard state.laser != on else { return }
        state.laser = on
        canvases.forEach { $0.setLaser(on) }
    }

    func perform(_ action: Action) {
        AppController.shared.perform(action)
    }

    // MARK: Palette

    func showPalette() {
        if palette == nil {
            let view = PaletteView(state: state) { [weak self] action in self?.perform(action) }
            let hosting = FirstMouseHostingView(rootView: view)
            let panel = FloatingPanel(contentView: hosting)
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.positioningPalette else { return }
                    self.paletteMovedByUser = true
                }
            })
            palette = panel
        }
        guard let palette else { return }
        palette.setContentSize(palette.contentView?.fittingSize ?? palette.frame.size)
        if !paletteMovedByUser, let screen = screenUnderMouse() {
            positioningPalette = true
            let size = palette.frame.size
            let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 10)
            palette.setFrameOrigin(origin)
            positioningPalette = false
        }
        palette.orderFrontRegardless()
    }

    func hidePalette() {
        palette?.orderOut(nil)
    }

    func togglePalette() {
        if let palette, palette.isVisible { hidePalette() } else { showPalette() }
    }

    // MARK: Cheat sheet

    func toggleCheatSheet() {
        if let cheatSheet, cheatSheet.isVisible {
            hideCheatSheet()
            return
        }
        if cheatSheet == nil {
            let hosting = FirstMouseHostingView(rootView: CheatSheetView())
            cheatSheet = FloatingPanel(contentView: hosting)
        }
        guard let cheatSheet, let screen = screenUnderMouse() else { return }
        cheatSheet.setContentSize(cheatSheet.contentView?.fittingSize ?? cheatSheet.frame.size)
        let size = cheatSheet.frame.size
        cheatSheet.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2))
        cheatSheet.orderFrontRegardless()
        state.cheatSheetVisible = true
    }

    func hideCheatSheet() {
        cheatSheet?.orderOut(nil)
        state.cheatSheetVisible = false
    }

    // MARK: Screenshots

    func screenshot(copy: Bool) {
        guard let window = windowUnderMouse() ?? windows.values.first else { return }
        let canvas = window.canvas
        let scale = window.backingScaleFactor
        let displayID = window.displayID
        hideCheatSheet()
        Task { @MainActor in
            do {
                let image = try await Screenshot.capture(displayID: displayID, scale: scale)
                if copy {
                    Screenshot.copyToPasteboard(image)
                    canvas.showToast("Copied screenshot to clipboard")
                } else {
                    let url = try Screenshot.saveToDesktop(image)
                    canvas.showToast("Saved \(url.lastPathComponent) to Desktop")
                }
            } catch {
                canvas.showToast("Screenshot failed. Allow Screen Recording for Chalk in System Settings.", seconds: 3)
            }
        }
    }
}

/// Lets buttons inside a non-activating panel respond to the first click.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
