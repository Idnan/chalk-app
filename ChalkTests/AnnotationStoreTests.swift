import XCTest
@testable import Chalk

@MainActor
final class AnnotationStoreTests: XCTestCase {
    private func stroke(_ pts: [CGPoint], width: CGFloat = 4) -> Annotation {
        Annotation(kind: .stroke(pts), color: Palette.colors[0], width: width)
    }

    func testAddUndoRedo() {
        let store = AnnotationStore()
        store.add(stroke([.zero, CGPoint(x: 10, y: 10)]))
        store.add(stroke([.zero, CGPoint(x: 20, y: 20)]))
        XCTAssertEqual(store.items.count, 2)
        store.undo()
        XCTAssertEqual(store.items.count, 1)
        store.redo()
        XCTAssertEqual(store.items.count, 2)
        store.undo(); store.undo()
        XCTAssertTrue(store.isEmpty)
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
    }

    func testNewActionClearsRedo() {
        let store = AnnotationStore()
        store.add(stroke([.zero, CGPoint(x: 10, y: 10)]))
        store.undo()
        store.add(stroke([.zero, CGPoint(x: 5, y: 5)]))
        XCTAssertFalse(store.canRedo)
    }

    func testClearIsUndoable() {
        let store = AnnotationStore()
        store.add(stroke([.zero, CGPoint(x: 10, y: 10)]))
        store.clear()
        XCTAssertTrue(store.isEmpty)
        store.undo()
        XCTAssertEqual(store.items.count, 1)
    }

    func testEraseRemovesOnlyTouchedItems() {
        let store = AnnotationStore()
        store.add(stroke([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]))
        store.add(stroke([CGPoint(x: 0, y: 200), CGPoint(x: 100, y: 200)]))
        let removed = store.erase(at: CGPoint(x: 50, y: 3), tolerance: 6)
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(store.items.count, 1)
        if case .stroke(let pts) = store.items[0].kind { XCTAssertEqual(pts[0].y, 200) } else { XCTFail() }
    }

    func testExpireDropsOldItemsWithoutUndoEntry() {
        let store = AnnotationStore()
        store.add(Annotation(kind: .stroke([.zero, CGPoint(x: 1, y: 1)]), color: Palette.colors[0], width: 2, createdAt: 0))
        store.add(Annotation(kind: .stroke([.zero, CGPoint(x: 1, y: 1)]), color: Palette.colors[0], width: 2, createdAt: 100))
        let undoDepthBefore = store.canUndo
        store.expire(olderThan: 10, now: 105)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.canUndo, undoDepthBefore)
    }

    func testChangeCallbackFires() {
        let store = AnnotationStore()
        var calls = 0
        store.onChange = { calls += 1 }
        store.add(stroke([.zero, CGPoint(x: 1, y: 1)]))
        store.undo()
        store.redo()
        store.clear()
        XCTAssertEqual(calls, 4)
    }
}
