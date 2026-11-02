import CoreGraphics
import UIKit

/// Rasterizes only the small idle line snapshot for Vision, then composes vector
/// handwriting centerlines back into the original character boxes.
enum HandwritingComposer {
    struct Snapshot {
        var image: CGImage
        var crop: CGRect
        var ids: Set<UUID>
        var revision: UInt64
        var source: [[InkPoint]]
    }

    static func snapshot(strokes: [InkStroke], revision: UInt64) -> Snapshot? {
        guard !strokes.isEmpty else { return nil }
        let source = strokes.map { $0.points }
        let ink = InkRibbon.unionBounds(source)
        let pad = max(8, ink.height * 0.18)
        let crop = ink.insetBy(dx: -pad, dy: -pad)
        guard crop.width > 1, crop.height > 1, crop.width < 20000, crop.height < 20000 else {
            return nil
        }
        let scale = min(3, 2048 / max(crop.width, crop.height))
        let width = Int((crop.width * scale).rounded(.up))
        let height = Int((crop.height * scale).rounded(.up))
        guard width > 0, height > 0, width * height <= 4_500_000,
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -crop.minX, y: -crop.minY)
        context.setFillColor(UIColor.black.cgColor)
        let path = CGMutablePath()
        for stroke in source { InkRibbon.append(to: path, points: stroke, origin: .zero) }
        context.addPath(path)
        context.fillPath()
        guard let image = context.makeImage() else { return nil }
        return Snapshot(
            image: image, crop: crop, ids: Set(strokes.map { $0.id }),
            revision: revision, source: source
        )
    }

    /// Conservative acceptance: confident, well-covered text only. Drawings,
    /// unsupported scripts and uncertain readings keep their original ink.
    static func compose(words: [RecognizedWord], source: [[InkPoint]]) -> [[InkPoint]]? {
        guard !words.isEmpty, !source.isEmpty else { return nil }
        let all = source.flatMap { $0 }
        guard let first = all.first else { return nil }
        let original = InkBounds(points: all.map { $0.position })
        let averageWidth = all.reduce(0) { $0 + $1.width } / Double(all.count)
        var result: [[InkPoint]] = []
        var covered = 0.0
        var acceptedCharacters = 0
        for word in words {
            guard word.confidence >= 0.72, word.glyphs.count >= max(1, word.text.count - 1) else {
                return nil
            }
            for glyph in word.glyphs {
                guard let template = HandwritingGlyphs.glyph(for: glyph.character) else { return nil }
                let box = glyph.bounds
                guard box.width > 0.5, box.height > 0.5,
                    box.width < original.width * 0.8 + 12,
                    box.height < original.height * 1.5 + 12
                else { return nil }
                let templateBounds = InkBounds(points: template.strokes.flatMap { $0 })
                guard templateBounds.width > 0.01 || templateBounds.height > 0.01 else { continue }
                let sx = box.width / max(templateBounds.width, 1)
                let sy = box.height / max(templateBounds.height, 1)
                for stroke in template.strokes {
                    var points = stroke.map { point in
                        InkPoint(
                            position: Vec2(
                                box.minX + (point.x - templateBounds.minX) * sx,
                                box.minY + (point.y - templateBounds.minY) * sy
                            ),
                            width: max(0.8, averageWidth * 0.92)
                        )
                    }
                    points = PolylineGeometry.resample(points, count: max(2, min(180, points.count * 5)))
                    let corners = CornerDetector.detect(
                        points: points.map { $0.position }, spacing: 1
                    )
                    for index in points.indices { points[index].isCorner = corners[index] }
                    result.append(points)
                }
                covered += box.width
                acceptedCharacters += 1
            }
        }
        guard acceptedCharacters >= 2, !result.isEmpty else { return nil }
        let target = InkBounds(points: result.flatMap { $0 }.map { $0.position })
        let allowed = original.expanded(by: max(6, original.height * 0.2))
        guard allowed.intersects(target),
            target.minX >= allowed.minX, target.maxX <= allowed.maxX,
            target.minY >= allowed.minY, target.maxY <= allowed.maxY,
            covered >= original.width * 0.45
        else { return nil }
        _ = first
        return result
    }

    /// Select the newest unrefined writing line, not the whole infinite page.
    static func pendingLine(in strokes: [InkStroke]) -> [InkStroke] {
        WritingLineGrouping.pendingLine(in: strokes)
    }
}
