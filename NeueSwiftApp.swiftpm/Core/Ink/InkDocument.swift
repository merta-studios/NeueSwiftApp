import Foundation

/// One logical stroke. Rendering may batch strokes, but history never merges them.
struct InkStroke: Identifiable, Equatable {
    let id: UUID
    var points: [InkPoint]
    var isRefined: Bool

    init(id: UUID = UUID(), points: [InkPoint], isRefined: Bool = false) {
        self.id = id
        self.points = points
        self.isRefined = isRefined
    }

    var bounds: InkBounds { InkBounds(points: points.map { $0.position }) }
}

/// Platform-independent rectangle (Core stays testable without CoreGraphics).
struct InkBounds: Equatable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    init(points: [Vec2]) {
        guard let first = points.first else {
            self.init(minX: 0, minY: 0, maxX: 0, maxY: 0)
            return
        }
        var box = InkBounds(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for point in points.dropFirst() {
            box.minX = min(box.minX, point.x)
            box.minY = min(box.minY, point.y)
            box.maxX = max(box.maxX, point.x)
            box.maxY = max(box.maxY, point.y)
        }
        self = box
    }

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var center: Vec2 { Vec2((minX + maxX) / 2, (minY + maxY) / 2) }
    var isEmpty: Bool { width <= 0 && height <= 0 }

    func expanded(by amount: Double) -> InkBounds {
        InkBounds(
            minX: minX - amount, minY: minY - amount,
            maxX: maxX + amount, maxY: maxY + amount
        )
    }

    func union(_ other: InkBounds) -> InkBounds {
        InkBounds(
            minX: min(minX, other.minX), minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX), maxY: max(maxY, other.maxY)
        )
    }

    func intersects(_ other: InkBounds) -> Bool {
        minX <= other.maxX && maxX >= other.minX
            && minY <= other.maxY && maxY >= other.minY
    }

    /// Vertical overlap relative to the shorter box; used to find a writing line.
    func verticalOverlapRatio(with other: InkBounds) -> Double {
        let overlap = min(maxY, other.maxY) - max(minY, other.minY)
        let shorter = max(0.01, min(height, other.height))
        return max(0, overlap) / shorter
    }
}

/// Copy-on-write document with atomic, stroke-identity-preserving history.
///
/// A whole refined line is one undo step. Undo never loses the original ink and
/// redo restores the exact refined result. Snapshots share unchanged point arrays.
final class InkDocument {
    private(set) var strokes: [InkStroke] = []
    private(set) var revision: UInt64 = 0
    private var undoStack: [[InkStroke]] = []
    private var redoStack: [[InkStroke]] = []
    let historyLimit: Int

    init(historyLimit: Int = 40) {
        self.historyLimit = max(1, historyLimit)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    @discardableResult
    func add(_ stroke: InkStroke) -> UUID {
        checkpoint()
        strokes.append(stroke)
        revision &+= 1
        return stroke.id
    }

    /// Atomically replaces a set of strokes. Returns false if any id disappeared.
    @discardableResult
    func replace(ids: Set<UUID>, with replacements: [InkStroke]) -> Bool {
        guard !ids.isEmpty, ids.allSatisfy({ id in strokes.contains { $0.id == id } }) else {
            return false
        }
        checkpoint()
        var inserted = false
        var result: [InkStroke] = []
        result.reserveCapacity(strokes.count + replacements.count)
        for stroke in strokes {
            if ids.contains(stroke.id) {
                if !inserted {
                    result.append(contentsOf: replacements)
                    inserted = true
                }
            } else {
                result.append(stroke)
            }
        }
        strokes = result
        revision &+= 1
        return true
    }

    @discardableResult
    func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(strokes)
        strokes = previous
        revision &+= 1
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(strokes)
        strokes = next
        revision &+= 1
        return true
    }

    func strokes(ids: Set<UUID>) -> [InkStroke] {
        strokes.filter { ids.contains($0.id) }
    }

    private func checkpoint() {
        undoStack.append(strokes)
        if undoStack.count > historyLimit { undoStack.removeFirst() }
        redoStack.removeAll(keepingCapacity: true)
    }
}
