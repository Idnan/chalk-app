import AppKit

/// Everything you can do while the overlay has keyboard focus.
enum Action: String, CaseIterable, Codable {
    case pen, highlighter, line, arrow, rectangle, ellipse, text, marker, eraser
    case laser, spotlight, whiteboard, fadeInk
    case color1, color2, color3, color4, color5, color6, color7, color8, color9
    case widthDown, widthUp
    case undo, redo, deleteLast, clear
    case copyScreenshot, saveScreenshot
    case freeze, cheatSheet, exit

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
        case .laser: "Laser pointer (hold)"
        case .spotlight: "Spotlight"
        case .whiteboard: "Whiteboard"
        case .fadeInk: "Fading ink"
        case .color1: "Red"
        case .color2: "Orange"
        case .color3: "Yellow"
        case .color4: "Green"
        case .color5: "Blue"
        case .color6: "Purple"
        case .color7: "Pink"
        case .color8: "Black"
        case .color9: "White"
        case .widthDown: "Thinner"
        case .widthUp: "Thicker"
        case .undo: "Undo"
        case .redo: "Redo"
        case .deleteLast: "Delete last"
        case .clear: "Clear all"
        case .copyScreenshot: "Copy screenshot"
        case .saveScreenshot: "Save screenshot to Desktop"
        case .freeze: "Freeze (click through)"
        case .cheatSheet: "Shortcut cheat sheet"
        case .exit: "Exit drawing"
        }
    }

    var defaultCombo: KeyCombo {
        switch self {
        case .pen: KeyCombo("p")
        case .highlighter: KeyCombo("h")
        case .line: KeyCombo("l")
        case .arrow: KeyCombo("a")
        case .rectangle: KeyCombo("r")
        case .ellipse: KeyCombo("o")
        case .text: KeyCombo("t")
        case .marker: KeyCombo("n")
        case .eraser: KeyCombo("e")
        case .laser: KeyCombo("space")
        case .spotlight: KeyCombo("s")
        case .whiteboard: KeyCombo("w")
        case .fadeInk: KeyCombo("f")
        case .color1: KeyCombo("1")
        case .color2: KeyCombo("2")
        case .color3: KeyCombo("3")
        case .color4: KeyCombo("4")
        case .color5: KeyCombo("5")
        case .color6: KeyCombo("6")
        case .color7: KeyCombo("7")
        case .color8: KeyCombo("8")
        case .color9: KeyCombo("9")
        case .widthDown: KeyCombo("[")
        case .widthUp: KeyCombo("]")
        case .undo: KeyCombo("z", command: true)
        case .redo: KeyCombo("z", command: true, shift: true)
        case .deleteLast: KeyCombo("delete")
        case .clear: KeyCombo("delete", command: true)
        case .copyScreenshot: KeyCombo("c", command: true)
        case .saveScreenshot: KeyCombo("s", command: true)
        case .freeze: KeyCombo("m")
        case .cheatSheet: KeyCombo("?", shift: true)
        case .exit: KeyCombo("escape")
        }
    }

    /// Key-repeat should keep firing these.
    var allowsRepeat: Bool {
        switch self {
        case .widthDown, .widthUp, .undo, .redo, .deleteLast: true
        default: false
        }
    }

    var colorIndex: Int? {
        switch self {
        case .color1: 0
        case .color2: 1
        case .color3: 2
        case .color4: 3
        case .color5: 4
        case .color6: 5
        case .color7: 6
        case .color8: 7
        case .color9: 8
        default: nil
        }
    }

    var tool: Tool? {
        switch self {
        case .pen: .pen
        case .highlighter: .highlighter
        case .line: .line
        case .arrow: .arrow
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .text: .text
        case .marker: .marker
        case .eraser: .eraser
        default: nil
        }
    }

    /// Grouping for the cheat sheet and settings list.
    static let sections: [(String, [Action])] = [
        ("Tools", [.pen, .highlighter, .line, .arrow, .rectangle, .ellipse, .text, .marker, .eraser]),
        ("Presenting", [.laser, .spotlight, .whiteboard, .fadeInk, .freeze]),
        ("Colors", [.color1, .color2, .color3, .color4, .color5, .color6, .color7, .color8, .color9]),
        ("Editing", [.widthDown, .widthUp, .undo, .redo, .deleteLast, .clear]),
        ("Other", [.copyScreenshot, .saveScreenshot, .cheatSheet, .exit]),
    ]
}

/// A key plus modifier set. `key` is a lowercase character or a named key: escape, delete, space, return, tab, left, right, up, down.
struct KeyCombo: Codable, Hashable, CustomStringConvertible {
    var key: String
    var command = false
    var shift = false
    var option = false
    var control = false

    init(_ key: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.key = key
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    private static let namedKeys: [UInt16: String] = [
        53: "escape", 51: "delete", 117: "forwarddelete", 49: "space", 36: "return", 76: "return",
        48: "tab", 123: "left", 124: "right", 125: "up", 126: "down",
    ]

    /// Builds a combo from a key event. Returns nil for bare modifier presses or unknown keys.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        command = flags.contains(.command)
        shift = flags.contains(.shift)
        option = flags.contains(.option)
        control = flags.contains(.control)
        if let named = Self.namedKeys[event.keyCode] {
            key = named
        } else if let chars = event.charactersIgnoringModifiers, let first = chars.first, !first.isWhitespace {
            key = String(first).lowercased()
        } else {
            return nil
        }
    }

    var description: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        switch key {
        case "escape": s += "⎋"
        case "delete": s += "⌫"
        case "forwarddelete": s += "⌦"
        case "space": s += "Space"
        case "return": s += "↩"
        case "tab": s += "⇥"
        case "left": s += "←"
        case "right": s += "→"
        case "up": s += "↑"
        case "down": s += "↓"
        default: s += key.uppercased()
        }
        return s
    }
}

/// User-editable bindings for in-overlay actions, persisted as JSON in UserDefaults.
@MainActor
final class KeyMap {
    static let shared = KeyMap()
    static let defaultsKey = "keyBindings"

    private(set) var bindings: [Action: KeyCombo]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var map = Dictionary(uniqueKeysWithValues: Action.allCases.map { ($0, $0.defaultCombo) })
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Action: KeyCombo].self, from: data) {
            map.merge(saved) { _, new in new }
        }
        bindings = map
    }

    func combo(for action: Action) -> KeyCombo { bindings[action] ?? action.defaultCombo }

    func action(for event: NSEvent) -> Action? {
        guard let combo = KeyCombo(event: event) else { return nil }
        return action(for: combo)
    }

    func action(for combo: KeyCombo) -> Action? {
        Action.allCases.first { bindings[$0] == combo }
    }

    /// Other actions currently bound to the same combo as `action`.
    func conflicts(for action: Action) -> [Action] {
        let combo = combo(for: action)
        return Action.allCases.filter { $0 != action && bindings[$0] == combo }
    }

    func set(_ combo: KeyCombo, for action: Action) {
        bindings[action] = combo
        save()
    }

    func resetToDefaults() {
        bindings = Dictionary(uniqueKeysWithValues: Action.allCases.map { ($0, $0.defaultCombo) })
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func save() {
        let changed = bindings.filter { $0.value != $0.key.defaultCombo }
        if let data = try? JSONEncoder().encode(changed) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
