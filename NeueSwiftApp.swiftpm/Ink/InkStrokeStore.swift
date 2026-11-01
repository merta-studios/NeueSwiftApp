import UIKit

/// Verwaltet die fertigen Striche als eigene Layer.
///
/// Ein Layer je Strich hält die Tinte beim Zoomen gestochen scharf (Vektor, kein
/// Bitmap). Damit die Zahl der Layer bei viel Text nicht unbegrenzt wächst,
/// werden die ältesten Striche zu einem gemeinsamen Layer zusammengefasst –
/// die neuesten bleiben einzeln, damit Zurücknehmen sie einzeln entfernen kann.
final class InkStrokeStore {
    private struct Entry {
        var points: [InkPoint]
        var layer: CAShapeLayer
        var path: CGPath
    }

    private var entries: [Entry] = []
    private let inkColor: UIColor
    /// Pixeldichte, in der die Konturen gerendert werden (Zoom × Bildschirm).
    var contentsScale: CGFloat = 2
    /// Ab dieser Anzahl wird zusammengefasst.
    private let mergeThreshold = 400
    private let mergeBatch = 200

    var count: Int { entries.count }

    init(inkColor: UIColor) {
        self.inkColor = inkColor
    }

    /// Einen fertigen Strich dauerhaft zeichnen.
    func add(_ points: [InkPoint], to container: CALayer, below liveLayer: CALayer) {
        guard !points.isEmpty, let entry = makeEntry(for: [points]) else { return }
        container.insertSublayer(entry.layer, below: liveLayer)
        entries.append(entry)
        if entries.count > mergeThreshold {
            mergeOldest(count: mergeBatch, in: container, below: liveLayer)
        }
    }

    /// Die letzten Striche – Grundlage für Verbindungen zwischen Buchstaben.
    func recent(limit: Int) -> [[InkPoint]] {
        guard limit > 0, !entries.isEmpty else { return [] }
        let start = max(0, entries.count - limit)
        return entries[start...].map { $0.points }
    }

    /// Nimmt den zuletzt gezeichneten Strich zurück.
    @discardableResult
    func removeLast() -> Bool {
        guard let last = entries.popLast() else { return false }
        last.layer.removeFromSuperlayer()
        return true
    }

    /// Sorgt dafür, dass die Tinte nach dem Zoomen wieder scharf gerendert wird.
    func refreshContents(displayScale: CGFloat, zoom: Double) {
        contentsScale = max(1, displayScale * CGFloat(min(3, max(1, zoom))))
        let scale = contentsScale
        for entry in entries {
            entry.layer.contentsScale = scale
            if let path = entry.layer.path {
                entry.layer.path = path
            }
        }
    }

    // MARK: - Zusammenfassen

    private func mergeOldest(count: Int, in container: CALayer, below liveLayer: CALayer) {
        guard entries.count > count + 4 else { return }
        let group = Array(entries.prefix(count))
        var strokes: [[InkPoint]] = []
        for entry in group {
            strokes.append(entry.points)
        }
        guard let merged = makeEntry(for: strokes) else { return }

        container.insertSublayer(merged.layer, below: liveLayer)
        for entry in group {
            entry.layer.removeFromSuperlayer()
        }

        var combinedPoints: [InkPoint] = []
        for stroke in strokes {
            combinedPoints.append(contentsOf: stroke)
        }
        let mergedEntry = Entry(
            points: combinedPoints, layer: merged.layer, path: merged.path
        )
        var updated: [Entry] = [mergedEntry]
        updated.append(contentsOf: entries.dropFirst(count))
        entries = updated
    }

    private func makeEntry(for strokes: [[InkPoint]]) -> Entry? {
        let box = InkRibbon.unionBounds(strokes)
        guard box.width.isFinite, box.height.isFinite else { return nil }
        guard box.width > 0 || box.height > 0 else { return nil }
        guard box.width < 40000, box.height < 40000 else { return nil }

        let path = CGMutablePath()
        for stroke in strokes {
            InkRibbon.append(to: path, points: stroke, origin: box.origin)
        }

        let layer = CAShapeLayer()
        layer.fillColor = inkColor.cgColor
        layer.strokeColor = nil
        layer.anchorPoint = .zero
        layer.position = box.origin
        layer.bounds = CGRect(origin: .zero, size: box.size)
        layer.path = path
        layer.contentsScale = max(1, contentsScale)
        layer.isOpaque = false

        var points: [InkPoint] = []
        for stroke in strokes {
            points.append(contentsOf: stroke)
        }
        return Entry(points: points, layer: layer, path: path)
    }
}
