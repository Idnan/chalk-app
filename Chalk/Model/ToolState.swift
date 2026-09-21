import Foundation
import Observation

enum Mode: Equatable {
    /// Overlay hidden.
    case off
    /// Overlay visible and capturing the mouse.
    case draw
    /// Overlay visible, clicks pass through to the apps underneath.
    case freeze
}

enum Whiteboard: Equatable {
    case none, white, black
}

/// Shared, observable UI state. Every overlay window and the palette read from this one instance.
@MainActor
@Observable
final class ToolState {
    var mode: Mode = .off
    var tool: Tool = .pen
    var colorIndex: Int = 0
    var width: CGFloat = CGFloat(Prefs.defaultWidth)
    var whiteboard: Whiteboard = .none
    var spotlight = false
    var laser = false
    var fadeInk = false
    var markerCount = 0
    var cheatSheetVisible = false

    var color: RGBA { Palette.colors[max(0, min(colorIndex, Palette.colors.count - 1))] }

    static let minWidth: CGFloat = 1
    static let maxWidth: CGFloat = 24
}
