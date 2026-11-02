import UIKit

/// Animates a whole recognized line while the original strokes stay hidden.
/// Commit is atomic: either the whole line becomes its refined vector form, or
/// the original ink is restored (undo, cancellation, stale recognition result).
final class LineMorph {
    let ids: Set<UUID>
    let target: [[InkPoint]]
    private var strokes: [LiveStroke] = []

    init?(ids: Set<UUID>, source: [[InkPoint]], target: [[InkPoint]], now: Double) {
        self.ids = ids
        self.target = target
        let pairs = StrokeMorphPlanner.plan(source: source, target: target)
        guard !pairs.isEmpty else { return nil }
        for pair in pairs {
            let stroke = LiveStroke()
            stroke.display = pair.source
            stroke.target = pair.target
            if stroke.beginMorph(now: now, duration: 0.5, wave: 0.1) {
                strokes.append(stroke)
            } else {
                stroke.display = pair.target
                strokes.append(stroke)
            }
        }
    }

    var visible: [[InkPoint]] { strokes.map { $0.display }.filter { !$0.isEmpty } }
    var isSettled: Bool { strokes.allSatisfy { $0.isSettled } }

    @discardableResult
    func advance(now: Double) -> Bool {
        var changed = false
        for stroke in strokes where stroke.advance(now: now) { changed = true }
        return changed
    }
}
