import SwiftUI
import KeyboardShortcuts

/// Overlay listing every binding. Toggled with the cheat sheet key (default `?`).
struct CheatSheetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "keyboard")
                Text("Chalk shortcuts").font(.title3.weight(.semibold))
                Spacer()
                Text("Shift constrains shapes · Option draws from center").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 28) {
                section("Global", globalRows)
                ForEach(Action.sections, id: \.0) { title, actions in
                    section(title, actions.map { ($0.label, KeyMap.shared.combo(for: $0).description) })
                }
            }
        }
        .padding(20)
        .frame(minWidth: 700)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .padding(6)
    }

    private var globalRows: [(String, String)] {
        [
            ("Toggle drawing", KeyboardShortcuts.getShortcut(for: .toggleDraw)?.description ?? "unset"),
            ("Toggle freeze", KeyboardShortcuts.getShortcut(for: .toggleFreeze)?.description ?? "unset"),
            ("Clear all displays", KeyboardShortcuts.getShortcut(for: .clearAll)?.description ?? "unset"),
        ]
    }

    private func section(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(rows, id: \.0) { label, key in
                HStack(spacing: 10) {
                    Text(key)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        .frame(minWidth: 44, alignment: .leading)
                    Text(label).font(.callout)
                }
            }
        }
    }
}
