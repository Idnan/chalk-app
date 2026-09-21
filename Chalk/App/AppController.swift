import AppKit
import KeyboardShortcuts

/// Single entry point for every user action, whether it came from a global hotkey, an overlay key, the palette or the menu.
@MainActor
final class AppController {
    static let shared = AppController()

    let state: ToolState
    let overlay: OverlayController
    private(set) var statusItem: StatusItemController?

    private init() {
        Prefs.registerDefaults()
        state = ToolState()
        overlay = OverlayController(state: state)
    }

    func start() {
        overlay.start()
        statusItem = StatusItemController(app: self)
        KeyboardShortcuts.onKeyUp(for: .toggleDraw) { [weak self] in self?.toggleDraw() }
        KeyboardShortcuts.onKeyUp(for: .toggleFreeze) { [weak self] in self?.toggleFreeze() }
        KeyboardShortcuts.onKeyUp(for: .clearAll) { [weak self] in self?.clearAll() }
    }

    // MARK: Modes

    func toggleDraw() {
        setMode(state.mode == .draw ? .off : .draw)
    }

    func toggleFreeze() {
        setMode(state.mode == .freeze ? .draw : .freeze)
    }

    func setMode(_ mode: Mode) {
        overlay.apply(mode: mode)
        statusItem?.update()
        if mode == .draw, !Prefs.shownShareHint {
            Prefs.shownShareHint = true
            overlay.currentCanvas?.showToast("Tip: share your whole screen, not a single window, so others see your drawings.", seconds: 5)
        }
    }

    func clearAll() {
        overlay.clearAll()
        overlay.refreshAll()
        statusItem?.update()
    }

    func setLaser(_ on: Bool) {
        overlay.setLaser(on)
    }

    // MARK: Actions

    func perform(_ action: Action) {
        if let tool = action.tool {
            state.tool = tool
        } else if let index = action.colorIndex {
            state.colorIndex = index
        } else {
            switch action {
            case .laser:
                break // hold-to-use; handled by CanvasView key down/up
            case .spotlight:
                state.spotlight.toggle()
            case .whiteboard:
                state.whiteboard = switch state.whiteboard {
                case .none: .white
                case .white: .black
                case .black: .none
                }
                // Keep ink visible against the board.
                if state.whiteboard == .white, Palette.names[state.colorIndex] == "White" { state.colorIndex = 7 }
                if state.whiteboard == .black, Palette.names[state.colorIndex] == "Black" { state.colorIndex = 8 }
            case .fadeInk:
                state.fadeInk.toggle()
                overlay.canvases.forEach { $0.invalidateCache() }
            case .widthDown:
                state.width = max(ToolState.minWidth, state.width - 1)
            case .widthUp:
                state.width = min(ToolState.maxWidth, state.width + 1)
            case .undo:
                overlay.currentCanvas?.store.undo()
            case .redo:
                overlay.currentCanvas?.store.redo()
            case .deleteLast:
                overlay.currentCanvas?.store.removeLast()
            case .clear:
                clearAll()
            case .copyScreenshot:
                overlay.screenshot(copy: true)
            case .saveScreenshot:
                overlay.screenshot(copy: false)
            case .freeze:
                setMode(.freeze)
                return
            case .cheatSheet:
                overlay.toggleCheatSheet()
            case .exit:
                setMode(.off)
                return
            default:
                break
            }
        }
        overlay.refreshAll()
    }
}
