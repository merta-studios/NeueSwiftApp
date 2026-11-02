import UIKit

/// Zoom und Verschiebung des Schreibbereichs.
///
/// Die Seite ist unbegrenzt: Es gibt keinen Rand, an dem das Schreiben
/// aufhört. `scale` und `offset` beschreiben, wie Seitenkoordinaten auf
/// Bildschirmpunkte abgebildet werden – dieselbe Abbildung benutzt der
/// Schreibbereich für die Tinte (Layer-Transformation), für Gesten und für die
/// Umrechnung der Stiftposition.
struct InkViewport {
    static let minimumScale: Double = 0.25
    static let maximumScale: Double = 10

    private(set) var scale: Double = 1
    /// Ursprung der Seite in Bildschirmkoordinaten.
    private(set) var offset = CGPoint.zero

    /// Seitenkoordinaten → Bildschirmkoordinaten.
    var transform: CGAffineTransform {
        CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)).concatenating(
            CGAffineTransform(translationX: offset.x, y: offset.y)
        )
    }

    /// Bildschirmpunkt → Seitenkoordinate.
    func pagePoint(_ point: CGPoint) -> Vec2 {
        Vec2(
            (Double(point.x) - Double(offset.x)) / scale,
            (Double(point.y) - Double(offset.y)) / scale
        )
    }

    /// Seitenkoordinate → Bildschirmpunkt.
    func viewPoint(_ point: Vec2) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x * scale + Double(offset.x)),
            y: CGFloat(point.y * scale + Double(offset.y))
        )
    }

    mutating func pan(dx: Double, dy: Double) {
        offset.x += CGFloat(dx)
        offset.y += CGFloat(dy)
    }

    /// Zoomt um einen festen Punkt: die Stelle unter den Fingern bleibt stehen.
    mutating func setScale(_ newScale: Double, anchor: CGPoint) {
        let clamped = InkMath.clamp(newScale, InkViewport.minimumScale, InkViewport.maximumScale)
        guard abs(clamped - scale) > 1e-6 else { return }
        let anchorOnPage = pagePoint(anchor)
        scale = clamped
        offset = CGPoint(
            x: anchor.x - CGFloat(anchorOnPage.x * scale),
            y: anchor.y - CGFloat(anchorOnPage.y * scale)
        )
    }

    mutating func reset() {
        scale = 1
        offset = .zero
    }
}
