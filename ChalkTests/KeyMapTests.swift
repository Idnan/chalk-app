import XCTest
@testable import Chalk

@MainActor
final class KeyMapTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "ChalkTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDefaultsAreUniqueExceptKnown() {
        let map = KeyMap(defaults: freshDefaults())
        for action in Action.allCases {
            XCTAssertTrue(map.conflicts(for: action).isEmpty, "\(action) conflicts with \(map.conflicts(for: action))")
        }
    }

    func testLookupByCombo() {
        let map = KeyMap(defaults: freshDefaults())
        XCTAssertEqual(map.action(for: KeyCombo("p")), .pen)
        XCTAssertEqual(map.action(for: KeyCombo("z", command: true)), .undo)
        XCTAssertEqual(map.action(for: KeyCombo("z", command: true, shift: true)), .redo)
        XCTAssertEqual(map.action(for: KeyCombo("escape")), .exit)
        XCTAssertNil(map.action(for: KeyCombo("p", command: true)))
    }

    func testRebindPersistsAndResets() {
        let defaults = freshDefaults()
        let map = KeyMap(defaults: defaults)
        map.set(KeyCombo("q"), for: .pen)
        XCTAssertEqual(map.action(for: KeyCombo("q")), .pen)
        XCTAssertNil(map.action(for: KeyCombo("p")))

        let reloaded = KeyMap(defaults: defaults)
        XCTAssertEqual(reloaded.combo(for: .pen), KeyCombo("q"))
        XCTAssertEqual(reloaded.combo(for: .undo), Action.undo.defaultCombo)

        reloaded.resetToDefaults()
        XCTAssertEqual(KeyMap(defaults: defaults).combo(for: .pen), KeyCombo("p"))
    }

    func testComboFromEvent() {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0,
                                     windowNumber: 0, context: nil, characters: "Z", charactersIgnoringModifiers: "Z",
                                     isARepeat: false, keyCode: 6)!
        XCTAssertEqual(KeyCombo(event: event), KeyCombo("z", command: true, shift: true))
        let esc = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                   windowNumber: 0, context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                                   isARepeat: false, keyCode: 53)!
        XCTAssertEqual(KeyCombo(event: esc)?.key, "escape")
    }

    func testDescription() {
        XCTAssertEqual(KeyCombo("z", command: true, shift: true).description, "⇧⌘Z")
        XCTAssertEqual(KeyCombo("delete", command: true).description, "⌘⌫")
        XCTAssertEqual(KeyCombo("space").description, "Space")
    }
}
