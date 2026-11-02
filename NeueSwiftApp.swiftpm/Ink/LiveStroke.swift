import UIKit

/// Ein Strich, der gerade geschrieben oder gerade korrigiert wird.
///
/// Der entscheidende Punkt für „die Linien verformen sich“: `display` sind die
/// Punkte, die tatsächlich auf dem Bildschirm liegen. Wenn der Stift abhebt,
/// wird `display` über eine kurze Wellenanimation in `target` überführt – die
/// Linie wandert also sichtbar in ihre schöne Form, statt ausgetauscht zu werden.
final class LiveStroke {
    /// Bestätigte Rohpunkte des Stifts (nur diese werden dauerhaft gespeichert).
    var inputs: [InkInput] = []
    /// Kurzfristige Vorschau-Samples; werden bei jedem Touch-Ereignis verworfen.
    var predictedInputs: [InkInput] = []
    /// Aktuell sichtbare Geometrie.
    var display: [InkPoint] = []
    /// Zielgeometrie nach der Aufbereitung.
    var target: [InkPoint] = []
    /// Der zugehörige Touch (nur während des Schreibens gesetzt).
    var touch: UITouch?
    /// `true`, wenn die Vorschau neu gerechnet werden muss.
    var needsPreview = true
    /// `true`, solange die Korrektur-Animation läuft.
    private(set) var isAnimating = false

    private var origin: [InkPoint] = []
    private var startTime: Double = 0
    private var duration: Double = 0.3
    private var wave: Double = 0.16

    var isEmpty: Bool { inputs.isEmpty && display.isEmpty && target.isEmpty }

    /// Startet die Verformung von der aktuellen zur schönen Linie.
    ///
    /// - Returns: `false`, wenn es nichts zu animieren gibt (z. B. ein Tupfer).
    func beginMorph(now: Double, duration: Double = 0.3, wave: Double = 0.16) -> Bool {
        guard target.count >= 2, !display.isEmpty else { return false }

        var differs = target.count != display.count
        if !differs {
            for index in 0..<min(target.count, display.count)
            where target[index].position != display[index].position {
                differs = true
                break
            }
        }
        guard differs else {
            display = target
            return false
        }

        origin = PolylineGeometry.resample(display, count: target.count)
        guard origin.count == target.count else { return false }
        display = origin
        startTime = now
        self.duration = max(0.05, duration)
        self.wave = max(0, wave)
        isAnimating = true
        return true
    }

    /// Rechnet die Animation weiter. `true`, wenn sich die Geometrie geändert hat.
    @discardableResult
    func advance(now: Double) -> Bool {
        guard isAnimating, target.count >= 2, origin.count == target.count else { return false }

        let count = target.count
        var updated = target
        var stillRunning = false
        for index in 0..<count {
            let progress = count > 1 ? Double(index) / Double(count - 1) : 0
            let delay = wave * progress
            let raw = (now - startTime - delay) / duration
            if raw < 1 {
                stillRunning = true
            }
            let eased = InkMath.easeOut(raw)
            if eased >= 1 {
                updated[index] = target[index]
                continue
            }
            let from = origin[index]
            let to = target[index]
            updated[index] = InkPoint(
                position: Vec2.lerp(from.position, to.position, eased),
                width: InkMath.lerp(from.width, to.width, eased),
                isCorner: eased > 0.5 ? to.isCorner : from.isCorner
            )
        }

        display = updated
        if !stillRunning {
            isAnimating = false
            display = target
        }
        return true
    }

    /// Fertig animiert oder gar nicht erst am Animieren?
    var isSettled: Bool { !isAnimating }
}
