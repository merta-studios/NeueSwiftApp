import Foundation

/// Geometrie auf Punktreihen: Bogenlänge, Resampling, Abstände.
enum PolylineGeometry {
    /// Kumulierte Bogenlänge; `result[0] == 0`, ein Eintrag pro Punkt.
    static func cumulativeLengths(_ points: [Vec2]) -> [Double] {
        var result = [Double](repeating: 0, count: points.count)
        guard points.count > 1 else { return result }
        var total = 0.0
        for i in 1..<points.count {
            total += points[i].distance(to: points[i - 1])
            result[i] = total
        }
        return result
    }

    static func totalLength(_ points: [Vec2]) -> Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += points[i].distance(to: points[i - 1])
        }
        return total
    }

    /// Sample-Index, der einer Bogenlänge am nächsten liegt.
    static func index(atLength length: Double, lengths: [Double]) -> Int {
        guard !lengths.isEmpty else { return 0 }
        if length <= 0 { return 0 }
        if length >= lengths[lengths.count - 1] { return lengths.count - 1 }

        var low = 0
        var high = lengths.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if lengths[middle] <= length {
                low = middle
            } else {
                high = middle
            }
        }
        return low
    }

    /// Punkt bei gegebener Bogenlänge (linear interpoliert).
    static func point(atLength length: Double, points: [Vec2]) -> Vec2 {
        guard points.count > 1 else { return points.first ?? Vec2.zero }
        let lengths = cumulativeLengths(points)
        let index = index(atLength: length, lengths: lengths)
        if index >= points.count - 1 { return points[points.count - 1] }
        let segment = lengths[index + 1] - lengths[index]
        guard segment > 1e-9 else { return points[index] }
        let t = (length - lengths[index]) / segment
        return Vec2.lerp(points[index], points[index + 1], t)
    }

    /// Resampling auf festen Abstand entlang der Bogenlänge.
    ///
    /// Die Begleitwerte (Druck, Tempo, Neigung) werden mitgeführt, damit der
    /// Strich an jeder Stelle weiß, wie stark er dort sein soll.
    static func resample(_ trace: InkTrace, spacing: Double) -> InkTrace {
        let source = trace.points
        guard source.count >= 2 else { return trace }
        let step = max(spacing, 0.05)

        var out = InkTrace()
        out.spacing = step
        out.points = [source[0]]
        out.pressures = [value(trace.pressures, 0)]
        out.speeds = [value(trace.speeds, 0)]
        out.altitudes = [value(trace.altitudes, 0)]

        var carry = 0.0
        for i in 1..<source.count {
            let a = source[i - 1]
            let b = source[i]
            let segment = a.distance(to: b)
            guard segment > 1e-9 else { continue }

            let pressureStart = value(trace.pressures, i - 1)
            let pressureEnd = value(trace.pressures, i)
            let speedStart = value(trace.speeds, i - 1)
            let speedEnd = value(trace.speeds, i)
            let altitudeStart = value(trace.altitudes, i - 1)
            let altitudeEnd = value(trace.altitudes, i)

            var travelled = 0.0
            while carry + (segment - travelled) >= step {
                let needed = step - carry
                travelled += needed
                let t = InkMath.clamp(travelled / segment, 0, 1)
                out.points.append(Vec2.lerp(a, b, t))
                out.pressures.append(InkMath.lerp(pressureStart, pressureEnd, t))
                out.speeds.append(InkMath.lerp(speedStart, speedEnd, t))
                out.altitudes.append(InkMath.lerp(altitudeStart, altitudeEnd, t))
                carry = 0
            }
            carry += segment - travelled
        }

        // Der letzte Originalpunkt soll nicht verloren gehen – sonst endet der
        // Strich sichtbar vor der Stiftspitze.
        if let last = source.last, let tail = out.points.last {
            if tail.distance(to: last) > step * 0.2 {
                out.points.append(last)
                out.pressures.append(value(trace.pressures, source.count - 1))
                out.speeds.append(value(trace.speeds, source.count - 1))
                out.altitudes.append(value(trace.altitudes, source.count - 1))
            }
        }
        return out
    }

    /// Resampling auf eine feste Punktzahl (für Morph-Zuordnung).
    static func resample(_ points: [Vec2], count: Int) -> [Vec2] {
        guard count > 1, points.count > 1 else { return points }
        if points.count == count { return points }
        let total = totalLength(points)
        guard total > 1e-9 else {
            return [Vec2](repeating: points[0], count: count)
        }
        var result = [Vec2](repeating: points[0], count: count)
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            result[i] = point(atLength: total * t, points: points)
        }
        return result
    }

    /// Resampling fertiger Linienpunkte auf eine feste Punktzahl.
    static func resample(_ points: [InkPoint], count: Int) -> [InkPoint] {
        guard count > 1, points.count > 1 else { return points }
        if points.count == count { return points }
        let total = totalLength(points.map { $0.position })
        guard total > 1e-9 else {
            return [InkPoint](repeating: points[0], count: count)
        }
        let lengths = cumulativeLengths(points.map { $0.position })
        var result = [InkPoint](repeating: points[0], count: count)
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let target = total * t
            let index = index(atLength: target, lengths: lengths)
            if index >= points.count - 1 {
                result[i] = points[points.count - 1]
                continue
            }
            let segment = lengths[index + 1] - lengths[index]
            let local = segment > 1e-9 ? (target - lengths[index]) / segment : 0
            let blended = InkMath.clamp(local, 0, 1)
            result[i] = InkPoint(
                position: Vec2.lerp(points[index].position, points[index + 1].position, blended),
                width: InkMath.lerp(points[index].width, points[index + 1].width, blended),
                isCorner: points[index].isCorner && blended < 0.5
            )
        }
        return result
    }

    /// Fußpunkt auf der Strecke `a`–`b` plus Parameter `t` in 0 … 1.
    static func closestPoint(onSegment a: Vec2, _ b: Vec2, to p: Vec2) -> (point: Vec2, t: Double) {
        let direction = b - a
        let lengthSquared = direction.lengthSquared
        guard lengthSquared > 1e-12 else { return (a, 0) }
        let t = InkMath.clamp((p - a).dot(direction) / lengthSquared, 0, 1)
        return (a + direction * t, t)
    }

    /// Nächster Punkt einer Polylinie: Abstand, Segmentindex und Fußpunkt.
    static func closestPointOnPolyline(
        _ p: Vec2, points: [Vec2]
    ) -> (distance: Double, index: Int, point: Vec2)? {
        guard points.count > 1 else {
            guard let only = points.first else { return nil }
            return (only.distance(to: p), 0, only)
        }
        var best: (distance: Double, index: Int, point: Vec2)?
        for i in 1..<points.count {
            let candidate = closestPoint(onSegment: points[i - 1], points[i], to: p)
            let distance = candidate.point.distance(to: p)
            if best == nil || distance < best!.distance {
                best = (distance, i - 1, candidate.point)
            }
        }
        return best
    }

    /// Streckenlänge einer Polylinie ab dem Start bis Index `index`.
    static func length(upTo index: Int, points: [Vec2]) -> Double {
        guard points.count > 1, index > 0 else { return 0 }
        let limit = min(index, points.count - 1)
        var total = 0.0
        for i in 1...limit {
            total += points[i].distance(to: points[i - 1])
        }
        return total
    }

    /// Douglas-Peucker: behält die formprägenden Punkte, wirft Zwischenpunkte weg.
    static func simplified(_ points: [Vec2], epsilon: Double) -> [Vec2] {
        guard points.count > 2, epsilon > 0 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack: [(Int, Int)] = [(0, points.count - 1)]

        while let (first, last) = stack.popLast() {
            guard last > first + 1 else { continue }
            var worst = 0.0
            var worstIndex = first
            for i in (first + 1)..<last {
                let foot = closestPoint(onSegment: points[first], points[last], to: points[i])
                let distance = foot.point.distance(to: points[i])
                if distance > worst {
                    worst = distance
                    worstIndex = i
                }
            }
            if worst > epsilon {
                keep[worstIndex] = true
                stack.append((first, worstIndex))
                stack.append((worstIndex, last))
            }
        }

        var result: [Vec2] = []
        for i in 0..<points.count where keep[i] {
            result.append(points[i])
        }
        if result.count < 2 { return [points[0], points[points.count - 1]] }
        return result
    }

    private static func value(_ values: [Double], _ index: Int) -> Double {
        guard index >= 0, index < values.count else { return values.last ?? 0 }
        return values[index]
    }
}
