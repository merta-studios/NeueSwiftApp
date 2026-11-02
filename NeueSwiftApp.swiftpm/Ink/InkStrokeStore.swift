import UIKit

/// Renders the logical document in bounded vector batches.
///
/// Batching is only a rendering detail: stroke identity and undo history live in
/// `InkDocument`, so replacing a refined line can never destroy older undo steps.
final class InkStrokeStore {
    let document = InkDocument()
    private let inkColor: UIColor
    private weak var container: CALayer?
    private weak var liveLayer: CALayer?
    private var layers: [CALayer] = []
    private var hiddenIDs: Set<UUID> = []
    private let batchSize = 64

    var contentsScale: CGFloat = 2 {
        didSet { rebuild() }
    }
    var strokes: [InkStroke] { document.strokes }
    var canUndo: Bool { document.canUndo }
    var canRedo: Bool { document.canRedo }
    var revision: UInt64 { document.revision }

    init(inkColor: UIColor) {
        self.inkColor = inkColor
    }

    func attach(to container: CALayer, below liveLayer: CALayer) {
        self.container = container
        self.liveLayer = liveLayer
        rebuild()
    }

    @discardableResult
    func add(_ points: [InkPoint]) -> UUID {
        let stroke = InkStroke(points: points)
        document.add(stroke)
        appendLayer(for: [stroke])
        if layers.count > 96 { rebuild() }
        return stroke.id
    }

    @discardableResult
    func replace(ids: Set<UUID>, with points: [[InkPoint]]) -> Bool {
        let replacements = points.map { InkStroke(points: $0, isRefined: true) }
        guard document.replace(ids: ids, with: replacements) else { return false }
        hiddenIDs.subtract(ids)
        rebuild()
        return true
    }

    @discardableResult
    func undo() -> Bool {
        guard document.undo() else { return false }
        hiddenIDs.removeAll()
        rebuild()
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard document.redo() else { return false }
        hiddenIDs.removeAll()
        rebuild()
        return true
    }

    func recent(limit: Int) -> [[InkPoint]] {
        Array(strokes.suffix(max(0, limit))).map { $0.points }
    }

    /// Hide source strokes while their morph is drawn on the live layer.
    func setHidden(_ ids: Set<UUID>, hidden: Bool) {
        if hidden { hiddenIDs.formUnion(ids) } else { hiddenIDs.subtract(ids) }
        rebuild()
    }

    func refreshContents(displayScale: CGFloat, zoom: Double) {
        let scale = max(1, displayScale * CGFloat(min(3, max(1, zoom))))
        if abs(scale - contentsScale) > 0.01 { contentsScale = scale }
    }

    func rebuild() {
        for layer in layers { layer.removeFromSuperlayer() }
        layers.removeAll()
        guard container != nil else { return }
        let visible = strokes.filter { !hiddenIDs.contains($0.id) }
        var start = 0
        while start < visible.count {
            let end = min(visible.count, start + batchSize)
            appendLayer(for: Array(visible[start..<end]))
            start = end
        }
    }

    private func appendLayer(for strokes: [InkStroke]) {
        guard let container, let liveLayer else { return }
        let paths = strokes.map { $0.points }
        let box = InkRibbon.unionBounds(paths)
        guard box.width.isFinite, box.height.isFinite, box.width > 0 || box.height > 0 else {
            return
        }
        let path = CGMutablePath()
        for points in paths { InkRibbon.append(to: path, points: points, origin: box.origin) }
        let layer = CAShapeLayer()
        layer.fillColor = inkColor.cgColor
        layer.strokeColor = nil
        layer.anchorPoint = .zero
        layer.position = box.origin
        layer.bounds = CGRect(origin: .zero, size: box.size)
        layer.path = path
        layer.contentsScale = max(1, contentsScale)
        container.insertSublayer(layer, below: liveLayer)
        layers.append(layer)
    }
}
