import Foundation

/// Aus „schnell und schmierig“ wird „schön“ – in einem festen Ablauf.
///
/// 1. Rohpunkte säubern (Doppelpunkte, Ausreißer) und gleichmäßig abtasten.
/// 2. Echte Ecken finden (die bleiben scharf).
/// 3. Gelernten Glättungskern anwenden.
/// 4. Tangentenrichtung glätten – der eigentliche Zittern-Killer.
/// 5. Fast-gerade und fast-runde Abschnitte sanft auf die Form ziehen.
/// 6. Endpunkte dort halten, wo der Stift sie gesetzt hat.
/// 7. Strichbreite aus Druck und Tempo aufbauen, weich auslaufen lassen.
/// 8. Überschwinger an den Enden entfernen, Neigung an das Profil angleichen.
struct StrokeBeautifier {
    /// Punktabstand der Aufbereitung in Seitenpunkten.
    var spacing: Double = 0.8
    /// Obergrenze für Punkte pro Strich (Performance).
    var maximumPoints: Int = 1400

    /// Die aufbereitete Linie für einen fertigen Strich.
    func beautify(
        _ inputs: [InkInput],
        style: WritingStyle,
        kernel: LearnedSmoothingKernel
    ) -> [InkPoint] {
        let prepared = prepare(inputs, style: style)
        guard prepared.trace.count >= 2 else {
            return dot(prepared.trace.points.first, style: style, inputs: inputs)
        }

        let totalLength = PolylineGeometry.totalLength(prepared.trace.points)
        guard totalLength > 0.75 else {
            return dot(prepared.trace.points[0], style: style, inputs: inputs)
        }

        let step = max(spacing, totalLength / Double(maximumPoints))
        let trace = PolylineGeometry.resample(prepared.trace, spacing: step)
        guard trace.count >= 2 else {
            return dot(trace.points.first, style: style, inputs: inputs)
        }

        let raw = trace.points
        let corners = CornerDetector.detect(points: raw, spacing: trace.spacing)
        var cleaned = kernel.apply(raw)
        cleaned = TangentSmoother.smooth(
            cleaned, corners: corners, sigma: style.smoothingSigma, spacing: trace.spacing
        )
        cleaned = ShapeSnapping.applyPerSegment(
            cleaned, corners: corners, tolerance: style.snapTolerance
        )
        cleaned = holdEndpoints(cleaned, target: raw, strength: 0.72)

        var points = buildPoints(
            positions: cleaned,
            trace: trace,
            corners: corners,
            style: style,
            hasPressure: prepared.hasPressure
        )
        points = TerminalTrimmer.trim(points)
        points = applySlant(points, style: style)
        return points
    }

    /// Die Live-Vorschau während des Schreibens.
    ///
    /// Bewusst leichtgewichtig: keine Eckenanalyse, keine Formanpassung – nur
    /// der gelernte Kern und die Breiten. Das Ergebnis ist die Linie, die der
    /// Schreiber sieht, während er schreibt.
    func preview(
        _ inputs: [InkInput],
        style: WritingStyle,
        kernel: LearnedSmoothingKernel
    ) -> [InkPoint] {
        guard inputs.count >= 2 else {
            return dot(inputs.first?.position, style: style, inputs: inputs)
        }
        let prepared = prepare(inputs, style: style)
        guard prepared.trace.count >= 2 else {
            return dot(prepared.trace.points.first, style: style, inputs: inputs)
        }

        // Dieselbe Abtastung wie in der Endfassung: so hat die
        // Morph-Animation später eine 1:1-Zuordnung und die Linie springt nicht.
        let totalLength = PolylineGeometry.totalLength(prepared.trace.points)
        let step = max(spacing, totalLength / Double(maximumPoints))
        let trace = PolylineGeometry.resample(prepared.trace, spacing: step)
        guard trace.count >= 2 else {
            return dot(prepared.trace.points.first, style: style, inputs: inputs)
        }

        let filtered = kernel.apply(trace.points, edge: .extrapolate)
        var points: [InkPoint] = []
        points.reserveCapacity(trace.count)
        for i in 0..<trace.count {
            let width = style.width(
                pressure: trace.pressures[i],
                hasPressure: prepared.hasPressure,
                speed: trace.speeds[i],
                altitude: trace.altitudes[i]
            )
            points.append(InkPoint(position: filtered[i], width: width))
        }
        return points
    }

    // MARK: - Vorbereitung

    struct Prepared {
        var trace: InkTrace
        var hasPressure: Bool
        var peakPressure: Double
        var medianSpeed: Double = 0
    }

    /// Säubert die Rohpunkte und baut eine gleichmäßig abgetastete Reihe.
    func prepare(_ inputs: [InkInput], style: WritingStyle) -> Prepared {
        var positions: [Vec2] = []
        var pressures: [Double] = []
        var altitudes: [Double] = []
        var times: [Double] = []
        var hasPressure = false
        var peakPressure = 0.0

        positions.reserveCapacity(inputs.count)
        for input in inputs {
            guard InkMath.isFinite(input.position) else { continue }
            if let last = positions.last, last.distance(to: input.position) < 0.03 {
                continue
            }
            positions.append(input.position)
            pressures.append(InkMath.clamp(input.pressure, 0, 1))
            altitudes.append(input.altitude)
            times.append(input.time)
            if input.hasPressure {
                hasPressure = true
                peakPressure = max(peakPressure, input.pressure)
            }
        }

        var trace = InkTrace()
        guard positions.count > 1 else {
            trace.points = positions
            trace.pressures = pressures
            trace.altitudes = altitudes
            trace.spacing = 1
            return Prepared(trace: trace, hasPressure: hasPressure, peakPressure: peakPressure)
        }

        positions = SignalFilters.median3(positions)
        trace.points = positions
        trace.pressures = pressures
        trace.altitudes = altitudes
        trace.spacing = 1
        trace.speeds = Self.speeds(positions: positions, times: times)

        var sortedSpeeds = trace.speeds
        sortedSpeeds.sort()
        let median = sortedSpeeds.isEmpty ? 0 : sortedSpeeds[sortedSpeeds.count / 2]
        return Prepared(
            trace: trace,
            hasPressure: hasPressure,
            peakPressure: peakPressure,
            medianSpeed: median
        )
    }

    /// Tempo je Punkt in Seitenpunkten pro Sekunde (zentrale Differenz).
    static func speeds(positions: [Vec2], times: [Double]) -> [Double] {
        let count = positions.count
        var speeds = [Double](repeating: 0, count: count)
        guard count > 1 else { return speeds }
        for i in 0..<count {
            let behind = max(0, i - 1)
            let ahead = min(count - 1, i + 1)
            let deltaTime = abs(times[ahead] - times[behind])
            guard deltaTime > 1e-5 else { continue }
            let distance = positions[ahead].distance(to: positions[behind])
            speeds[i] = InkMath.clamp(distance / deltaTime, 0, 6000)
        }
        return speeds
    }

    // MARK: - Aufbau der Linie

    /// Endpunkte dorthin ziehen, wo der Stift sie gesetzt hat.
    func holdEndpoints(_ points: [Vec2], target: [Vec2], strength: Double) -> [Vec2] {
        guard points.count == target.count, points.count >= 2, strength > 0 else { return points }
        let startDrift = (target[0] - points[0]) * strength
        let endDrift = (target[target.count - 1] - points[points.count - 1]) * strength
        var result = points
        for i in 0..<points.count {
            let t = Double(i) / Double(points.count - 1)
            result[i] += startDrift * (1 - t) + endDrift * t
        }
        return result
    }

    func buildPoints(
        positions: [Vec2],
        trace: InkTrace,
        corners: [Bool],
        style: WritingStyle,
        hasPressure: Bool
    ) -> [InkPoint] {
        let count = positions.count
        var widths = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let pressure = i < trace.pressures.count ? trace.pressures[i] : 0
            let speed = i < trace.speeds.count ? trace.speeds[i] : 0
            let altitude = i < trace.altitudes.count ? trace.altitudes[i] : Double.pi / 2
            widths[i] = style.width(
                pressure: pressure,
                hasPressure: hasPressure,
                speed: speed,
                altitude: altitude
            )
        }

        // Breite entlang der Linie beruhigen: sonst entstehen Tropfen.
        widths = SignalFilters.gaussianSmooth(widths, sigma: 1.6)

        // Weiches Auslaufen an beiden Enden – wie bei einem echten Stift.
        let taper = max(2, Int((2.6 / max(trace.spacing, 0.05)).rounded()))
        for i in 0..<count {
            let edge = min(i, count - 1 - i)
            let factor: Double
            if edge >= taper {
                factor = 1
            } else {
                let t = Double(edge) / Double(taper)
                factor = 0.42 + 0.58 * InkMath.smoothstep(0, 1, t)
            }
            widths[i] = InkMath.clamp(widths[i] * factor, 0.45, 6.5)
        }

        var points: [InkPoint] = []
        points.reserveCapacity(count)
        for i in 0..<count {
            let isCorner = i < corners.count ? corners[i] : false
            points.append(InkPoint(position: positions[i], width: widths[i], isCorner: isCorner))
        }
        return points
    }

    /// Neigung eines Strichs gegen die Senkrechte (Radiant, positiv = kursiv).
    ///
    /// Nur hohe, schmale Striche liefern eine belastbare Neigung – ein Punkt,
    /// ein „o“ oder eine Unterlänge sagen darüber nichts aus.
    static func slant(of points: [InkPoint]) -> Double? {
        guard points.count > 4 else { return nil }
        let positions = points.map { $0.position }
        guard let fit = PrimitiveFitting.fitLine(positions) else { return nil }

        var minY = positions[0].y
        var maxY = positions[0].y
        var minX = positions[0].x
        var maxX = positions[0].x
        for position in positions {
            minY = min(minY, position.y)
            maxY = max(maxY, position.y)
            minX = min(minX, position.x)
            maxX = max(maxX, position.x)
        }
        let height = maxY - minY
        let width = maxX - minX
        guard height > 9, width < 0.85 * height else { return nil }

        // Richtung nach oben drehen (y zeigt nach unten) und daraus die
        // Neigung gegen die Senkrechte bestimmen.
        var direction = fit.direction
        if direction.y > 0 {
            direction = direction * -1
        }
        let ownSlant = atan2(direction.x, -direction.y)
        guard ownSlant.isFinite, abs(ownSlant) < 0.8 else { return nil }
        return ownSlant
    }

    /// Neigung des Strichs an das gelernte Profil angleichen.
    func applySlant(_ points: [InkPoint], style: WritingStyle) -> [InkPoint] {
        guard points.count > 4, style.confidence > 0.05 else { return points }
        guard let ownSlant = StrokeBeautifier.slant(of: points) else { return points }

        var maxY = points[0].position.y
        var sumX = 0.0
        for point in points {
            maxY = max(maxY, point.position.y)
            sumX += point.position.x
        }

        let correction = InkMath.clamp(
            style.slant - ownSlant,
            -style.slantCorrectionLimit,
            style.slantCorrectionLimit
        )
        guard abs(correction) > 0.002 else { return points }

        let pivot = Vec2(sumX / Double(points.count), maxY)
        var result = points
        for i in 0..<result.count {
            let offset = result[i].position - pivot
            result[i].position = pivot + offset.rotated(by: correction)
        }
        return result
    }

    // MARK: - Hilfen

    /// Ein einzelner Tupfer (Punkt statt Strich).
    func dot(_ position: Vec2?, style: WritingStyle, inputs: [InkInput]) -> [InkPoint] {
        guard let position, InkMath.isFinite(position) else { return [] }
        let input = inputs.last
        let width = style.width(
            pressure: input?.pressure ?? 0,
            hasPressure: input?.hasPressure ?? false,
            speed: 0,
            altitude: input?.altitude ?? Double.pi / 2
        )
        return [InkPoint(position: position, width: width)]
    }
}
