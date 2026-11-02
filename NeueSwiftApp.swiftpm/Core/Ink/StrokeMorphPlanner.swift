import Foundation

/// A one-to-one animation pair. Both sides have the same sample count.
struct StrokeMorphPair {
    var source: [InkPoint]
    var target: [InkPoint]
}

/// Plans a continuous morph between two *sets* of strokes.
///
/// Recognition can turn one cursive stroke into several letters, or several
/// printed strokes into one ligature. Counts therefore differ. We duplicate the
/// shorter side along a monotone, spatially close assignment. Duplicated paths
/// converge exactly onto each other, so committing the target never pops.
enum StrokeMorphPlanner {
    static func plan(source: [[InkPoint]], target: [[InkPoint]]) -> [StrokeMorphPair] {
        let from = source.filter { !$0.isEmpty }
        let to = target.filter { !$0.isEmpty }
        guard !from.isEmpty, !to.isEmpty else { return [] }
        let count = max(from.count, to.count)
        let mapping = assign(
            sourceCount: from.count, targetCount: to.count, source: from, target: to)
        var pairs: [StrokeMorphPair] = []
        pairs.reserveCapacity(count)
        for index in 0..<count {
            let s = mapping[index].0
            let t = mapping[index].1
            let samples = min(320, max(2, max(from[s].count, to[t].count)))
            pairs.append(
                StrokeMorphPair(
                    source: PolylineGeometry.resample(from[s], count: samples),
                    target: PolylineGeometry.resample(to[t], count: samples)
                )
            )
        }
        return pairs
    }

    /// Monotone dynamic-programming alignment (no crossing letter assignments).
    private static func assign(
        sourceCount: Int, targetCount: Int, source: [[InkPoint]], target: [[InkPoint]]
    ) -> [(Int, Int)] {
        if sourceCount == targetCount {
            return Array(0..<sourceCount).map { ($0, $0) }
        }
        // Walk the longer side; each item chooses a non-decreasing index on the
        // shorter side. A small switch penalty keeps pieces of one source together.
        var result: [(Int, Int)] = []
        var previous = 0
        if sourceCount < targetCount {
            for t in 0..<targetCount {
                let ideal = Int(
                    Double(t) * Double(sourceCount - 1) / Double(max(1, targetCount - 1)))
                let lower = max(previous, ideal - 1)
                let upper = min(sourceCount - 1, ideal + 1)
                var best = lower
                var bestCost = Double.infinity
                let tb = InkBounds(points: target[t].map { $0.position })
                for s in lower...upper {
                    let sb = InkBounds(points: source[s].map { $0.position })
                    let cost = (sb.center - tb.center).length + (s != previous ? 0.5 : 0)
                    if cost < bestCost {
                        bestCost = cost
                        best = s
                    }
                }
                result.append((best, t))
                previous = best
            }
        } else {
            for s in 0..<sourceCount {
                let ideal = Int(
                    Double(s) * Double(targetCount - 1) / Double(max(1, sourceCount - 1)))
                let lower = max(previous, ideal - 1)
                let upper = min(targetCount - 1, ideal + 1)
                var best = lower
                var bestCost = Double.infinity
                let sb = InkBounds(points: source[s].map { $0.position })
                for t in lower...upper {
                    let tb = InkBounds(points: target[t].map { $0.position })
                    let cost = (sb.center - tb.center).length + (t != previous ? 0.5 : 0)
                    if cost < bestCost {
                        bestCost = cost
                        best = t
                    }
                }
                result.append((s, best))
                previous = best
            }
        }
        return result
    }
}
