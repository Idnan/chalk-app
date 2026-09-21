import SwiftUI

/// The floating tool strip shown while drawing. Every button routes through the same action dispatcher as the keyboard.
struct PaletteView: View {
    var state: ToolState
    var perform: (Action) -> Void

    private let tools: [(Tool, Action)] = [
        (.pen, .pen), (.highlighter, .highlighter), (.line, .line), (.arrow, .arrow),
        (.rectangle, .rectangle), (.ellipse, .ellipse), (.text, .text), (.marker, .marker), (.eraser, .eraser),
    ]
    private let colorActions: [Action] = [.color1, .color2, .color3, .color4, .color5, .color6, .color7, .color8, .color9]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tools, id: \.0) { tool, action in
                PaletteButton(symbol: tool.symbol, help: help(action), selected: state.tool == tool) { perform(action) }
            }
            separator
            ForEach(Array(colorActions.enumerated()), id: \.offset) { index, action in
                Button { perform(action) } label: {
                    ZStack {
                        Circle().fill(Color(nsColor: Palette.colors[index].nsColor))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
                        if state.colorIndex == index {
                            Circle().stroke(Color.primary, lineWidth: 2).frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(help(action))
            }
            separator
            PaletteButton(symbol: "minus", help: help(.widthDown), selected: false) { perform(.widthDown) }
            Circle().fill(Color(nsColor: state.color.nsColor))
                .frame(width: min(20, 4 + state.width), height: min(20, 4 + state.width))
                .frame(width: 22, height: 26)
                .help("Stroke width \(Int(state.width))")
            PaletteButton(symbol: "plus", help: help(.widthUp), selected: false) { perform(.widthUp) }
            separator
            PaletteButton(symbol: "arrow.uturn.backward", help: help(.undo), selected: false) { perform(.undo) }
            PaletteButton(symbol: "arrow.uturn.forward", help: help(.redo), selected: false) { perform(.redo) }
            PaletteButton(symbol: "trash", help: help(.clear), selected: false) { perform(.clear) }
            separator
            PaletteButton(symbol: "flashlight.on.fill", help: help(.spotlight), selected: state.spotlight) { perform(.spotlight) }
            PaletteButton(symbol: "timer", help: help(.fadeInk), selected: state.fadeInk) { perform(.fadeInk) }
            PaletteButton(symbol: whiteboardSymbol, help: help(.whiteboard), selected: state.whiteboard != .none) { perform(.whiteboard) }
            PaletteButton(symbol: "camera", help: help(.copyScreenshot), selected: false) { perform(.copyScreenshot) }
            separator
            PaletteButton(symbol: "cursorarrow.click.2", help: help(.freeze), selected: false) { perform(.freeze) }
            PaletteButton(symbol: "questionmark.circle", help: help(.cheatSheet), selected: state.cheatSheetVisible) { perform(.cheatSheet) }
            PaletteButton(symbol: "xmark", help: help(.exit), selected: false) { perform(.exit) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .padding(4)
    }

    private var separator: some View {
        Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 1, height: 18).padding(.horizontal, 3)
    }

    private var whiteboardSymbol: String {
        switch state.whiteboard {
        case .none: "rectangle.dashed"
        case .white: "rectangle.fill"
        case .black: "rectangle.inset.filled"
        }
    }

    private func help(_ action: Action) -> String {
        "\(action.label)  (\(KeyMap.shared.combo(for: action).description))"
    }
}

struct PaletteButton: View {
    var symbol: String
    var help: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .background(selected ? Color.accentColor.opacity(0.85) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
