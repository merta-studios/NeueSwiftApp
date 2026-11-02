import UIKit

/// Baut aus Linienpunkten eine gefüllte Kontur – das „Band“ der Feder.
///
/// Die Breite ist an jedem Punkt verschieden (Druck und Tempo), deshalb kann
/// keine Linie mit fester Stärke gezeichnet werden. Stattdessen entsteht links
/// und rechts der Mittellinie je ein Rand, die zusammen mit runden Endkappen
/// eine geschlossene Fläche bilden. An echten Ecken wird der Umriss eckig
/// geführt, sonst weich – so bleibt eine „n“-Spitze scharf und ein Bogen rund.
enum InkRibbon {
    /// Kleinste gezeichnete Breite (ein Strich darf nie ganz verschwinden).
    static let minimumWidth: Double = 0.6

    /// Begrenzung der Kontur in Seitenkoordinaten.
    static func bounds(_ points: [InkPoint], padding: Double = 3) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].position.x
        var maxX = minX
        var minY = points[0].position.y
        var maxY = minY
        var widest = minimumWidth
        for point in points {
            minX = min(minX, point.position.x)
            maxX = max(maxX, point.position.x)
            minY = min(minY, point.position.y)
            maxY = max(maxY, point.position.y)
            widest = max(widest, point.width)
        }
        let margin = widest / 2 + padding
        return CGRect(
            x: minX - margin,
            y: minY - margin,
            width: (maxX - minX) + 2 * margin,
            height: (maxY - minY) + 2 * margin
        )
    }

    /// Gemeinsame Begrenzung mehrerer Striche.
    static func unionBounds(_ strokes: [[InkPoint]]) -> CGRect {
        var result: CGRect?
        for stroke in strokes where !stroke.isEmpty {
            let box = bounds(stroke)
            if let current = result {
                result = current.union(box)
            } else {
                result = box
            }
        }
        return result ?? .zero
    }

    /// Hängt die Kontur eines Strichs an `path` an. `origin` wird abgezogen,
    /// damit die Kontur in den lokalen Koordinaten des Layers liegt.
    static func append(to path: CGMutablePath, points: [InkPoint], origin: CGPoint) {
        guard !points.isEmpty else { return }
        let originX = Double(origin.x)
        let originY = Double(origin.y)

        if points.count == 1 {
            appendDot(to: path, point: points[0], originX: originX, originY: originY)
            return
        }

        let corners = points.map { $0.isCorner }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        var normals: [Vec2] = []
        left.reserveCapacity(points.count)
        right.reserveCapacity(points.count)
        normals.reserveCapacity(points.count)

        for index in 0..<points.count {
            let normal = tangent(at: index, of: points).perpendicular
            normals.append(normal)
            let halfWidth = max(points[index].width, minimumWidth) / 2
            let leftPoint = points[index].position + normal * halfWidth
            let rightPoint = points[index].position - normal * halfWidth
            left.append(
                CGPoint(x: CGFloat(leftPoint.x - originX), y: CGFloat(leftPoint.y - originY))
            )
            right.append(
                CGPoint(x: CGFloat(rightPoint.x - originX), y: CGFloat(rightPoint.y - originY))
            )
        }

        let last = points.count - 1
        path.move(to: left[0])
        appendOutline(to: path, points: left, corners: corners)
        appendCap(
            to: path,
            center: CGPoint(
                x: CGFloat(points[last].position.x - originX),
                y: CGFloat(points[last].position.y - originY)
            ),
            radius: max(points[last].width, minimumWidth) / 2,
            startAngle: normals[last].angle,
            sweep: -Double.pi
        )
        appendOutline(to: path, points: Array(right.reversed()), corners: Array(corners.reversed()))
        appendCap(
            to: path,
            center: CGPoint(
                x: CGFloat(points[0].position.x - originX),
                y: CGFloat(points[0].position.y - originY)
            ),
            radius: max(points[0].width, minimumWidth) / 2,
            startAngle: normals[0].angle + Double.pi,
            sweep: -Double.pi
        )
        path.closeSubpath()
    }

    // MARK: - Bausteine

    private static func tangent(at index: Int, of points: [InkPoint]) -> Vec2 {
        let before = points[max(0, index - 1)].position
        let after = points[min(points.count - 1, index + 1)].position
        let direction = after - before
        guard direction.length > 1e-6 else { return Vec2(1, 0) }
        return direction.normalized
    }

    private static func appendOutline(
        to path: CGMutablePath, points: [CGPoint], corners: [Bool]
    ) {
        guard points.count >= 2 else { return }
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let isCorner =
                (index < corners.count && corners[index])
                || (index + 1 < corners.count && corners[index + 1])
            if isCorner || index == 0 || index == points.count - 2 {
                path.addLine(to: end)
                continue
            }
            let previous = points[index - 1]
            let next = points[index + 2]
            let control1 = CGPoint(
                x: start.x + (end.x - previous.x) / 6,
                y: start.y + (end.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: end.x - (next.x - start.x) / 6,
                y: end.y - (next.y - start.y) / 6
            )
            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }

    private static func appendCap(
        to path: CGMutablePath,
        center: CGPoint,
        radius: Double,
        startAngle: Double,
        sweep: Double
    ) {
        let segments = 10
        for step in 1...segments {
            let angle = startAngle + sweep * Double(step) / Double(segments)
            let point = CGPoint(
                x: Double(center.x) + cos(angle) * radius,
                y: Double(center.y) + sin(angle) * radius
            )
            path.addLine(to: point)
        }
    }

    private static func appendDot(
        to path: CGMutablePath, point: InkPoint, originX: Double, originY: Double
    ) {
        let radius = max(point.width, minimumWidth) / 2
        let centerX = point.position.x - originX
        let centerY = point.position.y - originY
        path.addEllipse(
            in: CGRect(
                x: centerX - radius,
                y: centerY - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }
}
