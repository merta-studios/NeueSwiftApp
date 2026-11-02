import Foundation

/// Ein Rohpunkt, wie ihn der Stift liefert – vor jeder Aufbereitung.
struct InkInput: Equatable, Sendable {
    /// Position in Seitenkoordinaten (nicht in Bildschirmpunkten).
    var position: Vec2
    /// Druck, normiert auf `maximumPossibleForce` des Geräts (0 … 1).
    var pressure: Double
    /// `true`, wenn das Gerät echten Stiftdruck liefert (Apple Pencil).
    var hasPressure: Bool
    /// Neigung des Stifts: π/2 = senkrecht auf dem Display.
    var altitude: Double
    /// Zeitstempel in Sekunden.
    var time: Double

    init(
        position: Vec2,
        pressure: Double = 0,
        hasPressure: Bool = false,
        altitude: Double = Double.pi / 2,
        time: Double = 0
    ) {
        self.position = position
        self.pressure = pressure
        self.hasPressure = hasPressure
        self.altitude = altitude
        self.time = time
    }
}

/// Ein Punkt der fertigen Linie: Position, Strichbreite, Eckenmarkierung.
///
/// Diese Punkte sind das Ergebnis der Beautifier-Kette und gleichzeitig die
/// Eingabe für den Renderer. Dieselbe Struktur trägt auch die Zwischenstände der
/// Morph-Animation, damit sich Linien *verformen* statt ersetzt zu werden.
struct InkPoint: Equatable, Sendable {
    var position: Vec2
    var width: Double
    var isCorner: Bool

    init(position: Vec2, width: Double, isCorner: Bool = false) {
        self.position = position
        self.width = width
        self.isCorner = isCorner
    }
}

/// Gleichmäßig abgetastete Punktreihe samt Begleitwerten.
///
/// Nach dem Resampling liegen alle Punkte im festen Abstand `spacing`
/// (Bogenlänge), was die gesamte weitere Verarbeitung stark vereinfacht:
/// Filter arbeiten in Samples, Krümmungen in Punktabständen.
struct InkTrace: Equatable, Sendable {
    var points: [Vec2] = []
    var pressures: [Double] = []
    var speeds: [Double] = []
    var altitudes: [Double] = []
    var spacing: Double = 1

    var isEmpty: Bool { points.count < 2 }

    var count: Int { points.count }

    /// Bogenlänge der abgetasteten Linie in Seitenpunkten.
    var length: Double { Double(max(0, points.count - 1)) * spacing }
}
