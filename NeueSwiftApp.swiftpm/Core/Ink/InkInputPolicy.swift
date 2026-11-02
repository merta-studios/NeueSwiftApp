import Foundation

/// The canvas input contract, kept in Core so it is regression-testable on Linux.
enum InkTouchKind: Equatable {
    case pencil
    case finger
    case other
}

enum InkInputPolicy {
    /// Fingers never draw, even before the first Pencil touch and in the simulator.
    static func acceptsWriting(_ kind: InkTouchKind) -> Bool { kind == .pencil }

    /// Navigation is a finger/pointer gesture, never a Pencil gesture.
    static func acceptsNavigation(_ kind: InkTouchKind) -> Bool { kind != .pencil }

    /// Predictions are preview-only and limited to a short horizon to avoid hooks.
    static func acceptsPrediction(sampleTime: Double, lastConfirmedTime: Double) -> Bool {
        sampleTime.isFinite && lastConfirmedTime.isFinite
            && sampleTime >= lastConfirmedTime && sampleTime <= lastConfirmedTime + 0.012
    }
}

/// Groups the newest unrefined strokes into one spatial writing line.
enum WritingLineGrouping {
    static func pendingLine(in strokes: [InkStroke]) -> [InkStroke] {
        guard let last = strokes.last(where: { !$0.isRefined }) else { return [] }
        let anchor = last.bounds
        guard anchor.height > 2 || anchor.width > 2 else { return [] }
        var selected: [InkStroke] = []
        for stroke in strokes.reversed() {
            if stroke.isRefined { break }
            let box = stroke.bounds
            let vertical = anchor.verticalOverlapRatio(with: box)
            let gap = max(anchor.minX - box.maxX, box.minX - anchor.maxX)
            if vertical < 0.35 || gap > max(80, anchor.height * 4) { break }
            selected.append(stroke)
            if selected.count >= 80 { break }
        }
        return selected.reversed()
    }
}
