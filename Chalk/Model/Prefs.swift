import Foundation

/// UserDefaults keys shared by the AppKit side and the SwiftUI settings screens.
enum Prefs {
    static let clearOnExitKey = "clearOnExit"
    static let showPaletteKey = "showPalette"
    static let fadeSecondsKey = "fadeSeconds"
    static let defaultWidthKey = "defaultWidth"
    static let spotlightRadiusKey = "spotlightRadius"
    static let shownShareHintKey = "shownShareHint"

    private static var d: UserDefaults { .standard }

    static func registerDefaults() {
        d.register(defaults: [
            clearOnExitKey: true,
            showPaletteKey: true,
            fadeSecondsKey: 4.0,
            defaultWidthKey: 4.0,
            spotlightRadiusKey: 140.0,
            shownShareHintKey: false,
        ])
    }

    static var clearOnExit: Bool { d.bool(forKey: clearOnExitKey) }
    static var showPalette: Bool { d.bool(forKey: showPaletteKey) }
    static var fadeSeconds: Double { d.double(forKey: fadeSecondsKey) }
    static var defaultWidth: Double { d.double(forKey: defaultWidthKey) }
    static var spotlightRadius: Double { d.double(forKey: spotlightRadiusKey) }
    static var shownShareHint: Bool {
        get { d.bool(forKey: shownShareHintKey) }
        set { d.set(newValue, forKey: shownShareHintKey) }
    }
}
