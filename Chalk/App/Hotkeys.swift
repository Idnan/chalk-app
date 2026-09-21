import KeyboardShortcuts

/// Global hotkeys. These work from any app without Accessibility permission.
extension KeyboardShortcuts.Name {
    static let toggleDraw = Self("toggleDraw", default: .init(.d, modifiers: [.control, .option]))
    static let toggleFreeze = Self("toggleFreeze", default: .init(.f, modifiers: [.control, .option]))
    static let clearAll = Self("clearAll", default: .init(.delete, modifiers: [.control, .option]))
}
