import UIKit

/// Der Schreibbereich: Papier, Tinte, Zoom, Verschieben – sonst nichts.
///
/// * Der **Apple Pencil** schreibt. Finger zoomen und verschieben (bis ein
///   Pencil benutzt wurde, darf auch der Finger schreiben – wichtig für den
///   Simulator).
/// * Die Tinte liegt in Seitenkoordinaten; Zoom und Verschiebung sind eine
///   Transformation der Ebene, die Tinte bleibt dabei Vektor und scharf.
/// * Während des Schreibens zeigt `liveLayer` die Live-Linie. Nach dem
///   Abheben wandert sie animiert in ihre aufbereitete Form und wird dann als
///   eigener Layer dauerhaft gezeichnet.
final class InkCanvasView: UIView, UIGestureRecognizerDelegate {
    /// Tinte: fast schwarz mit einem Stich ins Blaugraue (wirkt weicher als
    /// reines Schwarz auf warmem Papier).
    static let inkColor = UIColor(red: 0.11, green: 0.12, blue: 0.17, alpha: 1)
    /// Papier: warmes, leicht gebrochenes Weiß.
    static let paperColor = UIColor(red: 0.976, green: 0.968, blue: 0.949, alpha: 1)

    private let engine = InkEngine()
    private let store = InkStrokeStore(inkColor: InkCanvasView.inkColor)
    private let inkLayer = CALayer()
    private let liveLayer = CAShapeLayer()
    private let displayLinkProxy = DisplayLinkProxy()

    private var displayLink: CADisplayLink?
    private var viewport = InkViewport()
    private var activeStroke: LiveStroke?
    private var morphingStrokes: [LiveStroke] = []
    private var pinchStartScale: Double = 1
    private var pencilHasBeenUsed = false

    // MARK: - Aufbau

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        displayLink?.invalidate()
    }

    private func configure() {
        backgroundColor = InkCanvasView.paperColor
        isMultipleTouchEnabled = true
        isOpaque = true

        layer.addSublayer(inkLayer)
        inkLayer.anchorPoint = .zero
        inkLayer.position = .zero
        inkLayer.masksToBounds = false

        liveLayer.fillColor = InkCanvasView.inkColor.cgColor
        liveLayer.strokeColor = nil
        liveLayer.anchorPoint = .zero
        liveLayer.position = .zero
        liveLayer.contentsScale = max(1, traitCollection.displayScale)
        inkLayer.addSublayer(liveLayer)

        displayLinkProxy.handler = { [weak self] in
            self?.tick()
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let undo = UITapGestureRecognizer(target: self, action: #selector(handleUndoTap(_:)))
        undo.numberOfTouchesRequired = 3
        undo.delegate = self
        addGestureRecognizer(undo)

        let resetZoom = UITapGestureRecognizer(target: self, action: #selector(handleResetTap(_:)))
        resetZoom.numberOfTouchesRequired = 2
        resetZoom.numberOfTapsRequired = 2
        resetZoom.delegate = self
        addGestureRecognizer(resetZoom)

        applyViewport()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
        }
    }

    // MARK: - Eingabe

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard activeStroke == nil else { return }

        if let pencil = touches.first(where: { $0.type == .pencil }) {
            pencilHasBeenUsed = true
            beginStroke(with: pencil, event: event)
            return
        }
        // Ohne Pencil darf auch der Finger schreiben (Simulator, Test).
        guard !pencilHasBeenUsed, let finger = touches.first else { return }
        beginStroke(with: finger, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        collect(touch, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        collect(touch, event: event)
        finishActiveStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        collect(touch, event: event)
        finishActiveStroke()
    }

    /// Der Touch, der zum aktuellen Strich gehört (falls er dabei ist).
    private func activeTouch(in touches: Set<UITouch>) -> UITouch? {
        guard let stroke = activeStroke, let touch = stroke.touch else { return nil }
        guard touches.contains(where: { $0 === touch }) else { return nil }
        return touch
    }

    private func beginStroke(with touch: UITouch, event: UIEvent?) {
        let stroke = LiveStroke()
        stroke.touch = touch
        activeStroke = stroke
        collect(touch, event: event)
        startDisplayLink()
    }

    /// Sammelt alle Zwischenpunkte eines Touch-Ereignisses.
    ///
    /// `coalescedTouches` liefert die Zwischenabtastungen, die iOS
    /// zusammengefasst hat – beim Apple Pencil sind das bis zu 240 pro Sekunde.
    /// Ohne sie würde schnelles Schreiben eckig.
    private func collect(_ touch: UITouch, event: UIEvent?) {
        guard let stroke = activeStroke else { return }
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in samples {
            append(sample, to: stroke)
        }
        stroke.needsPreview = true
        startDisplayLink()
    }

    private func append(_ touch: UITouch, to stroke: LiveStroke) {
        let pagePoint = viewport.pagePoint(touch.location(in: self))
        let maximumForce = touch.maximumPossibleForce
        let usesPencil = touch.type == .pencil && maximumForce > 0
        let pressure = usesPencil ? Double(touch.force / maximumForce) : 0
        let input = InkInput(
            position: pagePoint,
            pressure: pressure,
            hasPressure: usesPencil,
            altitude: Double(touch.altitudeAngle),
            time: touch.timestamp
        )
        stroke.inputs.append(input)
    }

    // MARK: - Strich abschließen

    private func finishActiveStroke() {
        guard let stroke = activeStroke else { return }
        stroke.touch = nil
        activeStroke = nil
        defer { startDisplayLink() }

        guard !stroke.inputs.isEmpty else { return }
        var target = engine.finish(stroke.inputs)
        guard !target.isEmpty else { return }

        let neighbors = neighborStrokes()
        if !neighbors.isEmpty {
            let radius = weldRadius(for: target)
            target = JunctionWelder.weld(target, to: neighbors, radius: radius).points
        }
        stroke.target = target

        if stroke.beginMorph(now: CACurrentMediaTime()) {
            morphingStrokes.append(stroke)
        } else {
            commit(stroke)
        }
        redrawLiveLayer()
    }

    /// Striche, an die der neue Strich anschließen darf.
    private func neighborStrokes() -> [[InkPoint]] {
        var result = store.recent(limit: 4)
        for stroke in morphingStrokes where !stroke.target.isEmpty {
            result.append(stroke.target)
        }
        return result
    }

    private func weldRadius(for points: [InkPoint]) -> Double {
        var widest = 0.0
        for point in points {
            widest = max(widest, point.width)
        }
        return InkMath.clamp(1 + 0.9 * widest, 1.6, 4)
    }

    private func commit(_ stroke: LiveStroke) {
        let points = stroke.display.isEmpty ? stroke.target : stroke.display
        guard !points.isEmpty else { return }
        store.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
        store.add(points, to: inkLayer, below: liveLayer)
    }

    // MARK: - Animation

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(
            target: displayLinkProxy,
            selector: #selector(DisplayLinkProxy.step)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        var needsRedraw = false

        if let stroke = activeStroke, stroke.needsPreview {
            stroke.needsPreview = false
            let preview = engine.preview(stroke.inputs)
            if !preview.isEmpty {
                stroke.display = preview
                needsRedraw = true
            }
        }

        var stillMorphing: [LiveStroke] = []
        for stroke in morphingStrokes {
            if stroke.advance(now: now) {
                needsRedraw = true
            }
            if stroke.isSettled {
                commit(stroke)
            } else {
                stillMorphing.append(stroke)
            }
        }
        if stillMorphing.count != morphingStrokes.count {
            morphingStrokes = stillMorphing
            needsRedraw = true
        }

        if needsRedraw {
            redrawLiveLayer()
        }

        if activeStroke == nil && morphingStrokes.isEmpty {
            stopDisplayLink()
        }
    }

    private func redrawLiveLayer() {
        var visible: [[InkPoint]] = []
        if let stroke = activeStroke, !stroke.display.isEmpty {
            visible.append(stroke.display)
        }
        for stroke in morphingStrokes where !stroke.display.isEmpty {
            visible.append(stroke.display)
        }

        let box = InkRibbon.unionBounds(visible)
        guard !visible.isEmpty, box.width > 0.5 || box.height > 0.5 else {
            liveLayer.path = nil
            return
        }

        let path = CGMutablePath()
        for stroke in visible {
            InkRibbon.append(to: path, points: stroke, origin: box.origin)
        }
        liveLayer.bounds = CGRect(origin: .zero, size: box.size)
        liveLayer.position = box.origin
        liveLayer.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
        liveLayer.path = path
    }

    // MARK: - Zoom und Verschieben

    private func applyViewport() {
        inkLayer.setAffineTransform(viewport.transform)
        liveLayer.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .changed else { return }
        let translation = recognizer.translation(in: self)
        recognizer.setTranslation(.zero, in: self)
        viewport.pan(dx: Double(translation.x), dy: Double(translation.y))
        applyViewport()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartScale = viewport.scale
        case .changed:
            let anchor = recognizer.location(in: self)
            viewport.setScale(pinchStartScale * Double(recognizer.scale), anchor: anchor)
            applyViewport()
        case .ended, .cancelled, .failed:
            store.refreshContents(
                displayScale: traitCollection.displayScale, zoom: viewport.scale
            )
        default:
            break
        }
    }

    @objc private func handleResetTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        viewport.reset()
        applyViewport()
        store.refreshContents(displayScale: traitCollection.displayScale, zoom: viewport.scale)
    }

    @objc private func handleUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, activeStroke == nil else { return }
        if !morphingStrokes.isEmpty {
            morphingStrokes.removeLast()
            redrawLiveLayer()
            return
        }
        store.removeLast()
    }

    // MARK: - Gesten

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        // Der Stift gehört immer der Tinte, nie einer Geste.
        touch.type != .pencil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
