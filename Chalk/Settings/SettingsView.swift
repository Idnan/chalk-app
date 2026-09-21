import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 560)
    }
}

struct GeneralSettings: View {
    @AppStorage(Prefs.clearOnExitKey) private var clearOnExit = true
    @AppStorage(Prefs.showPaletteKey) private var showPalette = true
    @AppStorage(Prefs.fadeSecondsKey) private var fadeSeconds = 4.0
    @AppStorage(Prefs.defaultWidthKey) private var defaultWidth = 4.0
    @AppStorage(Prefs.spotlightRadiusKey) private var spotlightRadius = 140.0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .help("Start Chalk in the menu bar when you log in, so the hotkeys are always ready.")
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Toggle("Show the tool palette while drawing", isOn: $showPalette)
                    .help("The floating strip of tools and colors. Other people never see it in a screen share, only you do. Every button has a key, so you can turn it off once you know them.")
                Toggle("Clear drawings when exiting draw mode", isOn: $clearOnExit)
                    .help("On: pressing Esc or the draw hotkey wipes the screen. Off: drawings come back the next time you start drawing.")
                Text("Use Freeze to keep drawings on screen while you click through to other apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Drawing") {
                LabeledContent("Default stroke width") {
                    Slider(value: $defaultWidth, in: Double(ToolState.minWidth)...Double(ToolState.maxWidth), step: 1) { Text("") }
                        .frame(width: 200)
                        .help("Pen width when Chalk starts. Change it while drawing with [ and ]. Highlighter and text size scale with it.")
                    Text("\(Int(defaultWidth))").monospacedDigit().frame(width: 28)
                }
                LabeledContent("Fading ink duration") {
                    Slider(value: $fadeSeconds, in: 1...15, step: 1) { Text("") }.frame(width: 200)
                        .help("With fading ink on (F while drawing), each stroke disappears this many seconds after you draw it.")
                    Text("\(Int(fadeSeconds)) s").monospacedDigit().frame(width: 36)
                }
                LabeledContent("Spotlight radius") {
                    Slider(value: $spotlightRadius, in: 40...600, step: 10) { Text("") }.frame(width: 200)
                        .help("Size of the bright circle around the cursor when the spotlight (S) is on. Scrolling while it is on also changes this.")
                    Text("\(Int(spotlightRadius))").monospacedDigit().frame(width: 36)
                }
                Text("Scroll while the spotlight is on to resize it.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Screen sharing") {
                Text("Chalk's drawings are visible when you share your entire screen. Sharing a single window shows only that window, without the overlay. Screenshots need the Screen Recording permission, which macOS asks for the first time you use them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutSettings: View {
    @State private var version = 0

    var body: some View {
        Form {
            Section("Global (work from any app)") {
                KeyboardShortcuts.Recorder("Toggle drawing", name: .toggleDraw)
                    .help("Shows or hides the overlay from any app. Click the field and press the keys you want.")
                KeyboardShortcuts.Recorder("Toggle freeze", name: .toggleFreeze)
                    .help("Switches between drawing and freeze (drawings stay, clicks go through). Works from any app, which is how you get back from freeze.")
                KeyboardShortcuts.Recorder("Clear all displays", name: .clearAll)
                    .help("Wipes every drawing on every display without opening the overlay.")
            }
            ForEach(Action.sections, id: \.0) { title, actions in
                Section("\(title) (while drawing)") {
                    ForEach(actions, id: \.self) { action in
                        KeyBindingRow(action: action, version: $version)
                    }
                }
            }
            Section {
                Button("Reset drawing shortcuts to defaults") {
                    KeyMap.shared.resetToDefaults()
                    version += 1
                }
                .help("Restores the single-key defaults for every action in the sections above. Global hotkeys are not affected.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }
}

/// One editable row. Click Change, press the new key combination, done.
struct KeyBindingRow: View {
    let action: Action
    @Binding var version: Int
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        let _ = version
        let conflicts = KeyMap.shared.conflicts(for: action)
        HStack {
            Text(action.label)
            Spacer()
            if !conflicts.isEmpty {
                Text("also \(conflicts.map(\.label).joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.orange)
                    .help("This key is bound to more than one action. Only the first one listed in Settings will fire.")
            }
            Text(recording ? "Press keys…" : KeyMap.shared.combo(for: action).description)
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(minWidth: 70)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(recording ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            Button(recording ? "Cancel" : "Change") { recording ? stopRecording() : startRecording() }
                .controlSize(.small)
                .help(recording ? "Press the new key combination, or Esc to keep the current one." : "Rebind \(action.label). Any single key or combination works, including modifiers.")
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty, action != .exit {
                stopRecording()
                return nil
            }
            if let combo = KeyCombo(event: event) {
                KeyMap.shared.set(combo, for: action)
                version += 1
                stopRecording()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
