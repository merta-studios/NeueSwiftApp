import Foundation

/// Zweidimensionaler Vektor in Seitenkoordinaten (Punkte, y zeigt nach unten).
///
/// Bewusst ein eigener Typ statt `CGPoint`: `Core/` bleibt ohne CoreGraphics und
/// UIKit und lässt sich damit unter Linux mit echtem Compiler prüfen und testen
/// (siehe `Tests/run-core-tests.sh`). Die UIKit-Schicht rechnet an der Grenze um.
struct Vec2: Equatable, Sendable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = Vec2(0, 0)

    var lengthSquared: Double { x * x + y * y }

    var length: Double { lengthSquared.squareRoot() }

    /// Einheitsvektor; `zero` für einen Vektor der Länge 0.
    var normalized: Vec2 {
        let l = length
        guard l > 1e-12 else { return Vec2.zero }
        return Vec2(x / l, y / l)
    }

    /// Um 90° gedreht – in y-nach-unten-Koordinaten zeigt das nach links.
    var perpendicular: Vec2 { Vec2(-y, x) }

    func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    /// z-Komponente des Kreuzprodukts; Vorzeichen = Drehrichtung.
    func cross(_ other: Vec2) -> Double { x * other.y - y * other.x }

    func distance(to other: Vec2) -> Double { (other - self).length }

    var angle: Double { atan2(y, x) }

    func rotated(by radians: Double) -> Vec2 {
        let c = cos(radians)
        let s = sin(radians)
        return Vec2(x * c - y * s, x * s + y * c)
    }

    static func atAngle(_ radians: Double, length: Double = 1) -> Vec2 {
        Vec2(cos(radians) * length, sin(radians) * length)
    }

    static func lerp(_ a: Vec2, _ b: Vec2, _ t: Double) -> Vec2 {
        Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }

    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }

    static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }

    static func * (s: Double, a: Vec2) -> Vec2 { Vec2(a.x * s, a.y * s) }

    static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }

    static func += (a: inout Vec2, b: Vec2) { a = a + b }

    static func -= (a: inout Vec2, b: Vec2) { a = a - b }
}

/// Kleine Rechenhelfer, gebündelt damit im globalen Namensraum nichts kollidiert.
enum InkMath {
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        if value < lower { return lower }
        if value > upper { return upper }
        return value
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
        let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }

    /// Ease-out für Animationen: schnell starten, weich auslaufen.
    static func easeOut(_ t: Double) -> Double {
        let c = clamp(t, 0, 1)
        let inv = 1 - c
        return 1 - inv * inv * inv
    }

    /// Winkel auf (-π, π] normalisieren.
    static func wrap(_ angle: Double) -> Double {
        var value = angle
        let twoPi = 2 * Double.pi
        while value <= -Double.pi { value += twoPi }
        while value > Double.pi { value -= twoPi }
        return value
    }

    /// Winkelreihe entrollen, damit benachbarte Werte nicht um 2π springen.
    static func unwrap(_ angles: [Double]) -> [Double] {
        var result = angles
        guard result.count > 1 else { return result }
        var offset = 0.0
        for i in 1..<result.count {
            let delta = angles[i] + offset - result[i - 1]
            let wrapped = wrap(delta)
            offset += wrapped - delta
            result[i] = angles[i] + offset
        }
        return result
    }

    static func isFinite(_ vector: Vec2) -> Bool {
        vector.x.isFinite && vector.y.isFinite
    }
}
