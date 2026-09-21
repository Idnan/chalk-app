import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

/// A transparent, full-display panel that sits above everything (including fullscreen apps and the menu bar).
/// It is a non-activating panel so it can take keyboard focus without pulling focus away from the app being presented.
final class OverlayWindow: NSPanel {
    let canvas: CanvasView
    let displayID: CGDirectDisplayID

    init(screen: NSScreen, canvas: CanvasView) {
        self.canvas = canvas
        self.displayID = screen.displayID
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false
        sharingType = .readOnly   // keep it visible to screen sharing
        isExcludedFromWindowsMenu = true
        contentView = canvas
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Small floating panel (palette, cheat sheet). Hidden from screen sharing so viewers only see the ink.
final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(contentRect: NSRect(origin: .zero, size: contentView.fittingSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        sharingType = .none
        isExcludedFromWindowsMenu = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
