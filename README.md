# Chalk

Draw on your Mac's screen while you share it.

Chalk lives in the menu bar. Press a hotkey and a transparent canvas covers every display, on top of whatever you are presenting, fullscreen apps included. Sketch with a pen, highlighter, arrows, shapes, text and numbered markers. Point with a laser, spotlight what matters, or freeze your drawings and keep clicking through to your apps underneath. Every tool has a single-key shortcut and the app needs no special permissions.

## Features

- **Tools:** pen, highlighter, line, arrow, rectangle, ellipse, text, numbered step markers, stroke eraser.
- **Presenting:** laser pointer with a fading trail, spotlight that dims everything except a circle around the cursor, whiteboard (white or black background), fading ink that erases itself a few seconds after you draw.
- **Freeze mode:** drawings stay on screen while clicks and typing pass through to the apps below.
- **Multi-display:** one canvas per screen, rebuilt automatically when displays change.
- **Keyboard first:** nine colors on the number keys, width on the bracket keys, undo and redo, a cheat sheet on `?`. Every binding can be changed in Settings.
- **Screenshots:** copy or save the annotated screen. This is the only feature that asks for a permission (Screen Recording).
- **Menu bar only:** no Dock icon, optional launch at login.

## Screen sharing

Chalk's drawings are visible when the other side sees your **entire screen**. Sharing a single window shows only that window, without the overlay. This applies to every overlay tool and every meeting app, so pick "share screen" rather than "share window". The floating palette and the cheat sheet are hidden from screen capture, so viewers only see the ink.

## Shortcuts

Global hotkeys work from any app and can be recorded in Settings.

| Hotkey | Action |
|---|---|
| ⌃⌥D | Toggle drawing |
| ⌃⌥F | Toggle freeze (click through) |
| ⌃⌥⌫ | Clear all displays |

While the overlay is up, single keys select tools and options. Defaults:

| Key | Action | Key | Action |
|---|---|---|---|
| P | Pen | 1 to 9 | Colors |
| H | Highlighter | [ and ] | Thinner, thicker |
| L | Line | ⌘Z, ⇧⌘Z | Undo, redo |
| A | Arrow | ⌫ | Delete last |
| R | Rectangle | ⌘⌫ | Clear all |
| O | Ellipse | Space (hold) | Laser pointer |
| T | Text | S | Spotlight (scroll to resize) |
| N | Step marker | W | Whiteboard (white, black, off) |
| E | Eraser | F | Fading ink |
| M | Freeze | ⌘C, ⌘S | Copy or save screenshot |
| ? | Cheat sheet | Esc | Exit drawing |

Hold Shift to constrain shapes (square, circle, 45° lines) and Option to draw from the center.

## Requirements

- macOS 14 or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project: `brew install xcodegen`
- `librsvg` only if you want to regenerate the icons: `brew install librsvg`

## Setup

```bash
git clone git@github.com:Idnan/chalk-app.git
cd chalk-app
make run
```

`make run` generates `Chalk.xcodeproj` from `project.yml`, builds a Debug app into `build/` and launches it. The project file is generated and not committed, so open it in Xcode with `make gen` followed by `open Chalk.xcodeproj` if you prefer the IDE.

Other targets:

```bash
make gen      # regenerate the Xcode project
make build    # Debug build without launching
make test     # unit tests
make release  # Release build
make clean    # remove build output
```

Debug builds are signed ad hoc for local use. Set your team and a Developer ID identity in `project.yml` before distributing.

## How it works

Chalk is a Swift app that mixes SwiftUI for the palette and settings with AppKit for the windows and drawing.

**Overlay windows.** For each display the app creates a borderless, transparent `NSPanel` at screen-saver level that joins every Space and can sit over fullscreen apps. The panel is non-activating, so it can take keyboard input while the app you are presenting stays the active app, and it is marked shareable so screen capture includes it. Freeze mode just flips `ignoresMouseEvents` on those panels.

**Drawing.** Each panel hosts a `CanvasView`. Committed annotations are rendered once into a cached `CGLayer`; only the stroke in progress is redrawn while you drag, which keeps hundreds of strokes smooth. Freehand ink is smoothed with quadratic curves through segment midpoints. Laser, spotlight, fading ink and toasts are drawn on top by a display timer that only runs while one of them is active.

**Model.** An `Annotation` is a value type holding its kind (stroke, highlight, line, arrow, rectangle, ellipse, text, marker), color, width and creation time, plus geometry helpers for bounds and hit testing. An `AnnotationStore` per display keeps the list with snapshot undo and redo.

**Input.** Global hotkeys are Carbon hotkeys through the KeyboardShortcuts package, which is why no Accessibility permission is needed. Keys pressed on the overlay are looked up in a `KeyMap`, a user-editable table stored in `UserDefaults`. Every action from the keyboard, the palette or the menu goes through one dispatcher, `AppController.perform`, so all three stay in sync.

**Menu bar.** An AppKit `NSStatusItem` whose icon, tooltip and menu titles change with the mode. The menu shows the live hotkeys as key equivalents.

### Source layout

```
Chalk/
  App/        entry point, status item, action dispatcher, global hotkey names
  Model/      Annotation, AnnotationStore, ToolState, KeyMap, Prefs
  Overlay/    OverlayWindow, CanvasView, OverlayController, PaletteView, CheatSheetView
  Rendering/  Renderer (Core Graphics), Screenshot (ScreenCaptureKit)
  Settings/   SwiftUI settings: general, hotkeys, key rebinding
  Resources/  asset catalog (app icon, menu bar images)
ChalkTests/   unit tests for the model, geometry and key bindings
Design/       source SVGs and the composed app icon
scripts/      generate-icons.py
```

## Icons

The app icon and menu bar images are generated from the SVGs in `Design/` by `scripts/generate-icons.py`. The glyphs are "cartoon blackboard chalk" and "cartoon chalk stick" from [koboyo.com](https://koboyo.com), free for commercial use without attribution.

## Permissions

None are required to draw. Copying or saving a screenshot uses ScreenCaptureKit, and macOS asks for Screen Recording the first time you do it.
