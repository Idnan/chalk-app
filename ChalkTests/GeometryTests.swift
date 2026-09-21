import XCTest
@testable import Chalk

final class GeometryTests: XCTestCase {
    func testSmoothPathHandlesDegenerateInputs() {
        XCTAssertTrue(Geometry.smoothPath([]).isEmpty)
        XCTAssertFalse(Geometry.smoothPath([CGPoint(x: 5, y: 5)]).isEmpty)
        let two = Geometry.smoothPath([.zero, CGPoint(x: 10, y: 0)])
        XCTAssertEqual(two.boundingBoxOfPath.width, 10, accuracy: 0.01)
    }

    func testSmoothPathPassesThroughEndpoints() {
        let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 30), CGPoint(x: 20, y: 0), CGPoint(x: 30, y: 30)]
        let box = Geometry.smoothPath(pts).boundingBoxOfPath
        XCTAssertEqual(box.minX, 0, accuracy: 0.01)
        XCTAssertEqual(box.maxX, 30, accuracy: 0.01)
    }

    func testConstrainAngleSnapsTo45Degrees() {
        let end = Geometry.constrainAngle(start: .zero, end: CGPoint(x: 100, y: 10))
        XCTAssertEqual(end.y, 0, accuracy: 0.001)
        XCTAssertEqual(end.x, hypot(100, 10), accuracy: 0.001)
        let diag = Geometry.constrainAngle(start: .zero, end: CGPoint(x: 100, y: 90))
        XCTAssertEqual(diag.x, diag.y, accuracy: 0.001)
    }

    func testDragRectSquareAndCenter() {
        let square = Geometry.dragRect(start: .zero, end: CGPoint(x: 40, y: -10), square: true, fromCenter: false)
        XCTAssertEqual(square.width, 40); XCTAssertEqual(square.height, 40)
        XCTAssertEqual(square.minY, -40)
        let centered = Geometry.dragRect(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 60, y: 70), square: false, fromCenter: true)
        XCTAssertEqual(centered, CGRect(x: 40, y: 30, width: 20, height: 40))
    }

    func testArrowHeadGeometry() {
        let head = Geometry.arrowHead(from: .zero, to: CGPoint(x: 100, y: 0), width: 4)
        XCTAssertEqual(head.tip, CGPoint(x: 100, y: 0))
        XCTAssertEqual(head.base.x, 84, accuracy: 0.001)
        XCTAssertEqual(head.left.y, -head.right.y, accuracy: 0.001)
    }

    func testHitTestRectangleOutlineOnly() {
        let a = Annotation(kind: .rectangle(CGRect(x: 0, y: 0, width: 100, height: 100)), color: Palette.colors[0], width: 4)
        XCTAssertTrue(a.hitTest(CGPoint(x: 0, y: 50), tolerance: 4))
        XCTAssertFalse(a.hitTest(CGPoint(x: 50, y: 50), tolerance: 4))
    }

    func testHitTestMarkerAndText() {
        let marker = Annotation(kind: .marker(1, CGPoint(x: 50, y: 50)), color: Palette.colors[0], width: 4)
        XCTAssertTrue(marker.hitTest(CGPoint(x: 55, y: 55), tolerance: 0))
        XCTAssertFalse(marker.hitTest(CGPoint(x: 90, y: 90), tolerance: 0))
        let text = Annotation(kind: .text("Hello", CGPoint(x: 10, y: 100)), color: Palette.colors[0], width: 4)
        XCTAssertTrue(text.hitTest(CGPoint(x: 15, y: 95), tolerance: 0))
        XCTAssertFalse(text.hitTest(CGPoint(x: 15, y: 120), tolerance: 0))
    }
}
