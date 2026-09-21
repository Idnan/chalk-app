import Foundation

/// Annotations for one display, with snapshot undo/redo.
@MainActor
final class AnnotationStore {
    private(set) var items: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private let maxUndo = 200

    /// Called after every mutation so the canvas can drop its cache.
    var onChange: (() -> Void)?

    var isEmpty: Bool { items.isEmpty }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func add(_ annotation: Annotation) {
        snapshot()
        items.append(annotation)
        onChange?()
    }

    func removeLast() {
        guard !items.isEmpty else { return }
        snapshot()
        items.removeLast()
        onChange?()
    }

    func clear() {
        guard !items.isEmpty else { return }
        snapshot()
        items.removeAll()
        onChange?()
    }

    /// Removes every annotation touching `point`. Returns how many were removed.
    @discardableResult
    func erase(at point: CGPoint, tolerance: CGFloat) -> Int {
        let hits = items.filter { $0.hitTest(point, tolerance: tolerance) }
        guard !hits.isEmpty else { return 0 }
        snapshot()
        let ids = Set(hits.map(\.id))
        items.removeAll { ids.contains($0.id) }
        onChange?()
        return hits.count
    }

    /// Drops annotations older than `age` seconds without touching undo history (used by fading ink).
    func expire(olderThan age: TimeInterval, now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        let before = items.count
        items.removeAll { now - $0.createdAt > age }
        if items.count != before { onChange?() }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(items)
        items = previous
        onChange?()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(items)
        items = next
        onChange?()
    }

    private func snapshot() {
        undoStack.append(items)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }
}
