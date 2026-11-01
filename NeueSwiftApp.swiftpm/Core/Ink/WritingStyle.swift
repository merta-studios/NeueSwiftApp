import Foundation

/// Das gelernte Schreibprofil – die App passt sich dem Schreiber an.
///
/// Alles hier ist eine laufende Statistik über die eigenen Striche: Zittern,
/// Neigung, typischer Druck, typisches Tempo. Es wird nichts gespeichert und
/// nichts hochgeladen; das Profil entsteht in der Sitzung und wird mit jedem
/// Strich genauer. Die abgeleiteten Werte (Glättungsstärke, Neigungskorrektur)
/// sind damit keine fest verdrahteten Zahlen, sondern folgen dem Schreiber.
struct WritingStyle: Equatable {
    /// Anzahl der eingeflossenen Striche.
    private(set) var strokeCount: Int = 0
    /// Typische Neigung in Radiant; positiv = nach rechts (kursiv).
    private(set) var slant: Double = 0.14
    /// Gelernte Zitterstärke in Seitenpunkten (hochfrequent).
    private(set) var tremor: Double = 0.16
    /// Druck, der als „voll“ gilt (90. Perzentil der Stiftdrücke).
    private(set) var pressureReference: Double = 0.32
    /// Typisches Schreibtempo in Seitenpunkten pro Sekunde.
    private(set) var speedReference: Double = 420
    /// Grundstrichbreite der Feder in Seitenpunkten.
    var baseWidth: Double = 2.35

    init(baseWidth: Double = 2.35) {
        self.baseWidth = baseWidth
    }

    /// Wie sicher das Profil ist (0 … 1). Am Anfang wird nur wenig korrigiert.
    var confidence: Double { InkMath.clamp(Double(strokeCount) / 10, 0, 1) }

    /// Glättungsstärke in Seitenpunkten, abgeleitet aus dem gelernten Zittern.
    var smoothingSigma: Double { InkMath.clamp(1.45 + 8.5 * tremor, 1.45, 4.4) }

    /// Wie stark Formen (Gerade, Kreis) nachgezogen werden.
    var snapTolerance: Double { InkMath.clamp(0.42 + 0.5 * tremor, 0.42, 0.8) }

    /// Wie weit die Neigung korrigiert werden darf (Radiant, gedeckelt).
    var slantCorrectionLimit: Double { 0.055 * confidence }

    /// Strichbreite an einer Stelle.
    ///
    /// - Parameters:
    ///   - pressure: Rohdruck des Geräts (0 … 1).
    ///   - hasPressure: `false` bei Finger oder Simulator.
    ///   - speed: Tempo in Seitenpunkten pro Sekunde.
    ///   - altitude: Stiftneigung (π/2 = senkrecht).
    func width(
        pressure: Double,
        hasPressure: Bool,
        speed: Double,
        altitude: Double
    ) -> Double {
        let normalizedPressure: Double
        if hasPressure {
            normalizedPressure = InkMath.clamp(
                pressure / max(pressureReference, 0.06), 0, 1.15
            )
        } else {
            normalizedPressure = 0.82
        }
        let normalizedSpeed = InkMath.clamp(speed / max(speedReference, 1), 0, 1.2)
        let pressurePart = 0.62 + 0.38 * pow(normalizedPressure, 0.65)
        let speedPart = 1 - 0.2 * normalizedSpeed
        let tilt = InkMath.clamp(altitude / (Double.pi / 2), 0, 1)
        let tiltPart = 1 + 0.16 * (1 - tilt)
        let width = baseWidth * pressurePart * speedPart * tiltPart
        return InkMath.clamp(width, 0.55, 6.5)
    }

    /// Ein Strich ist fertig: Profil nachführen.
    mutating func observe(
        tremor sample: Double,
        slant slantSample: Double?,
        peakPressure: Double,
        hasPressure: Bool,
        medianSpeed: Double
    ) {
        strokeCount += 1
        let rate = max(0.08, 1 / Double(min(strokeCount, 14)))

        if sample.isFinite, sample >= 0 {
            tremor += (InkMath.clamp(sample, 0, 1.2) - tremor) * rate
        }
        if let slantSample, slantSample.isFinite {
            let difference = InkMath.wrap(slantSample - slant)
            slant = InkMath.wrap(slant + difference * rate * 0.8)
            slant = InkMath.clamp(slant, -0.5, 0.6)
        }
        if hasPressure, peakPressure > 0.02 {
            pressureReference += (peakPressure - pressureReference) * rate * 0.6
            pressureReference = InkMath.clamp(pressureReference, 0.1, 0.9)
        }
        if medianSpeed > 1 {
            speedReference += (medianSpeed - speedReference) * rate * 0.5
            speedReference = InkMath.clamp(speedReference, 90, 2400)
        }
    }

    /// Setzt das Profil zurück (z. B. nach einem Neustart des Schreibbereichs).
    mutating func reset() {
        self = WritingStyle(baseWidth: baseWidth)
    }
}
