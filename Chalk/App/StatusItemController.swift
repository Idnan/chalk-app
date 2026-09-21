import AppKit
import KeyboardShortcuts

/// The menu bar item. AppKit rather than MenuBarExtra so the icon and every menu item can carry a tooltip,
/// and so the menu shows the live global hotkeys as key equivalents.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let drawItem = NSMenuItem(title: "", action: #selector(toggleDraw), keyEquivalent: "")
    private let freezeItem = NSMenuItem(title: "", action: #selector(toggleFreeze), keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "Clear All Drawings", action: #selector(clearAll), keyEquivalent: "")
    private let cheatItem = NSMenuItem(title: "Show Shortcut Cheat Sheet", action: #selector(showCheatSheet), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: "Quit Chalk", action: #selector(quit), keyEquivalent: "q")

    private unowned let app: AppController

    init(app: AppController) {
        self.app = app
        super.init()
        for menuItem in [drawItem, freezeItem, clearItem, cheatItem, settingsItem, quitItem] { menuItem.target = self }
        drawItem.setShortcut(for: .toggleDraw)
        freezeItem.setShortcut(for: .toggleFreeze)
        clearItem.setShortcut(for: .clearAll)
        clearItem.toolTip = "Remove every drawing on every display. Undo is not possible after this."
        cheatItem.toolTip = "Overlay listing every key you can press while drawing. Press ? on the overlay for the same thing."
        settingsItem.toolTip = "Hotkeys, key bindings, launch at login, fading ink and other preferences."
        quitItem.toolTip = "Quit Chalk. Drawings are not saved."

        menu.delegate = self
        menu.items = [drawItem, freezeItem, clearItem, .separator(), cheatItem, .separator(), settingsItem, quitItem]
        item.menu = menu
        item.behavior = .removalAllowed
        update()
    }

    /// Refreshes the icon, tooltip and menu titles for the current mode. Called after every mode change.
    func update() {
        let mode = app.state.mode
        let draw = shortcut(.toggleDraw), freeze = shortcut(.toggleFreeze)
        if let button = item.button {
            let name: String
            switch mode {
            case .off: name = "MenuBarOff"
            case .draw: name = "MenuBarDraw"
            case .freeze: name = "MenuBarFreeze"
            }
            let image = NSImage(named: name) ?? NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: nil)
            image?.isTemplate = true
            image?.accessibilityDescription = "Chalk"
            button.image = image
            button.toolTip = switch mode {
            case .off: "Chalk is off. Press \(draw) to draw on your screen."
            case .draw: "Chalk is drawing. Press Esc or \(draw) to stop, \(freeze) to freeze."
            case .freeze: "Chalk is frozen: drawings stay visible and clicks go through to your apps. Press \(freeze) or \(draw) to draw again."
            }
        }
        drawItem.title = mode == .draw ? "Stop Drawing" : "Start Drawing"
        drawItem.toolTip = mode == .draw
            ? "Hide the overlay. Drawings are cleared unless you turned that off in Settings."
            : "Show the drawing overlay on every display. Focus stays with the app you are presenting."
        freezeItem.title = mode == .freeze ? "Unfreeze (Back to Drawing)" : "Freeze (Click Through)"
        freezeItem.toolTip = mode == .freeze
            ? "Capture the mouse again so you can keep drawing."
            : "Keep the drawings on screen but let clicks and typing pass through to your apps."
        clearItem.isEnabled = app.overlay.hasAnnotations
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        update()
    }

    private func shortcut(_ name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name)?.description ?? "the hotkey set in Settings"
    }

    // MARK: Actions

    @objc private func toggleDraw() { app.toggleDraw() }
    @objc private func toggleFreeze() { app.toggleFreeze() }
    @objc private func clearAll() { app.clearAll() }
    @objc private func showCheatSheet() {
        if app.state.mode == .off { app.setMode(.draw) }
        if !app.state.cheatSheetVisible { app.overlay.toggleCheatSheet() }
    }
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
