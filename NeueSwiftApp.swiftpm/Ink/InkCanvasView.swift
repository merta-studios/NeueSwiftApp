import UIKit

/// Custom infinite canvas. Pencil writes; fingers only navigate.
///
/// The live path uses coalesced + short-horizon predicted pencil samples. Only
/// confirmed samples are committed. Idle handwriting recognition is debounced,
/// revision-checked and atomic; it never blocks or rewrites an active stroke.
@MainActor
final class InkCanvasView: UIView, UIGestureRecognizerDelegate {
    static let inkColor = UIColor(red: 0.11, green: 0.12, blue: 0.17, alpha: 1)
    static let paperColor = UIColor(red: 0.976, green: 0.968, blue: 0.949, alpha: 1)

    weak var controller: InkCanvasController? {
        didSet { bindController() }
    }

    private let engine = InkEngine()
    private let store = InkStrokeStore(inkColor: InkCanvasView.inkColor)
    private let recognition = HandwritingRecognition()
    private let inkLayer = CALayer()
    private let liveLayer = CAShapeLayer()
    private let displayLinkProxy = DisplayLinkProxy()

    private var displayLink: CADisplayLink?
    private var viewport = InkViewport()
    private var activeStroke: LiveStroke?
    private var morphingStrokes: [LiveStroke] = []
    private var lineMorph: LineMorph?
    private var recognitionTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pinchStartScale: Double = 1
    private var isRefining = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        // CADisplayLink is cleaned up by DisplayLinkProxy on its next tick;
        // touching it here is not allowed from a nonisolated Swift 6 deinit.
        recognitionTask?.cancel()
        debounceTask?.cancel()
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
        store.attach(to: inkLayer, below: liveLayer)

        displayLinkProxy.owner = self
        displayLinkProxy.handler = { [weak self] in self?.tick() }

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

        let redo = UITapGestureRecognizer(target: self, action: #selector(handleRedoTap(_:)))
        redo.numberOfTouchesRequired = 3
        redo.numberOfTapsRequired = 2
        redo.delegate = self
        addGestureRecognizer(redo)
        undo.require(toFail: redo)

        let resetZoom = UITapGestureRecognizer(target: self, action: #selector(handleResetTap(_:)))
        resetZoom.numberOfTouchesRequired = 2
        resetZoom.numberOfTapsRequired = 2
        resetZoom.delegate = self
        addGestureRecognizer(resetZoom)

        applyViewport()
    }

    private func bindController() {
        controller?.onUndo = { [weak self] in self?.performUndo() }
        controller?.onRedo = { [weak self] in self?.performRedo() }
        controller?.onRefine = { [weak self] in self?.refineNow() }
        controller?.onToggleRefinement = { [weak self] enabled in
            guard let self else { return }
            if enabled {
                self.scheduleRefinement()
            } else {
                self.cancelRecognition()
                self.publishStatus("Automatische Schriftkorrektur aus")
            }
        }
        publishStatus()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
            debounceTask?.cancel()
        } else if activeStroke != nil || !morphingStrokes.isEmpty || lineMorph != nil {
            startDisplayLink()
        }
    }

    // MARK: - Pencil input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard activeStroke == nil,
            let pencil = touches.first(where: { InkInputPolicy.acceptsWriting(Self.kind(of: $0)) })
        else {
            return
        }
        cancelRecognition()
        let stroke = LiveStroke()
        stroke.touch = pencil
        activeStroke = stroke
        collect(pencil, event: event)
        startDisplayLink()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        collect(touch, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        collect(touch, event: event, includePredictions: false)
        finishActiveStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let touch = activeTouch(in: touches) else { return }
        // A cancelled touch still keeps its confirmed ink; predictions are discarded.
        collect(touch, event: event, includePredictions: false)
        finishActiveStroke()
    }

    private func activeTouch(in touches: Set<UITouch>) -> UITouch? {
        guard let stroke = activeStroke, let touch = stroke.touch,
            InkInputPolicy.acceptsWriting(Self.kind(of: touch))
        else {
            return nil
        }
        return touches.contains(where: { $0 === touch }) ? touch : nil
    }

    private func collect(_ touch: UITouch, event: UIEvent?, includePredictions: Bool = true) {
        guard let stroke = activeStroke, InkInputPolicy.acceptsWriting(Self.kind(of: touch)) else {
            return
        }
        stroke.predictedInputs.removeAll(keepingCapacity: true)
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            append(sample, to: stroke, predicted: false)
        }
        if includePredictions, let last = stroke.inputs.last {
            for sample in event?.predictedTouches(for: touch) ?? [] {
                guard
                    InkInputPolicy.acceptsPrediction(
                        sampleTime: sample.timestamp, lastConfirmedTime: last.time
                    )
                else { break }
                append(sample, to: stroke, predicted: true)
                if stroke.predictedInputs.count >= 4 { break }
            }
        }
        stroke.needsPreview = true
        startDisplayLink()
    }

    private func append(_ touch: UITouch, to stroke: LiveStroke, predicted: Bool) {
        let pagePoint = viewport.pagePoint(touch.preciseLocation(in: self))
        let maximumForce = touch.maximumPossibleForce
        let hasPressure = maximumForce > 0
        let input = InkInput(
            position: pagePoint,
            pressure: hasPressure ? Double(touch.force / maximumForce) : 0,
            hasPressure: hasPressure,
            altitude: Double(touch.altitudeAngle),
            time: touch.timestamp
        )
        if predicted {
            stroke.predictedInputs.append(input)
        } else {
            stroke.inputs.append(input)
        }
    }

    // MARK: - Stroke completion

    private func finishActiveStroke() {
        guard let stroke = activeStroke else { return }
        stroke.touch = nil
        stroke.predictedInputs.removeAll()
        activeStroke = nil
        defer { startDisplayLink() }
        guard !stroke.inputs.isEmpty else { return }
        var target = engine.finish(stroke.inputs)
        guard !target.isEmpty else { return }
        let neighbors = neighborStrokes()
        if !neighbors.isEmpty {
            target =
                JunctionWelder.weld(target, to: neighbors, radius: weldRadius(for: target)).points
        }
        stroke.target = target
        if stroke.beginMorph(now: CACurrentMediaTime()) {
            morphingStrokes.append(stroke)
        } else {
            commit(stroke)
        }
        redrawLiveLayer()
        scheduleRefinement()
    }

    private func neighborStrokes() -> [[InkPoint]] {
        var result = store.recent(limit: 4)
        for stroke in morphingStrokes where !stroke.target.isEmpty { result.append(stroke.target) }
        return result
    }

    private func weldRadius(for points: [InkPoint]) -> Double {
        let widest = points.reduce(0.0) { max($0, $1.width) }
        return InkMath.clamp(0.8 + 0.6 * widest, 1.4, 3)
    }

    private func commit(_ stroke: LiveStroke) {
        let points = stroke.display.isEmpty ? stroke.target : stroke.display
        guard !points.isEmpty else { return }
        store.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
        store.add(points)
        publishStatus()
    }

    // MARK: - Idle handwriting refinement

    private func scheduleRefinement() {
        debounceTask?.cancel()
        guard controller?.refinementEnabled ?? true, window != nil else { return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self?.refineNow()
        }
    }

    private func cancelRecognition() {
        debounceTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        if lineMorph == nil { isRefining = false }
    }

    private func refineNow() {
        guard recognitionTask == nil, lineMorph == nil, activeStroke == nil,
            morphingStrokes.isEmpty
        else { return }
        let line = HandwritingComposer.pendingLine(in: store.strokes)
        guard !line.isEmpty,
            let snapshot = HandwritingComposer.snapshot(
                strokes: line, revision: store.revision
            )
        else { return }
        isRefining = true
        publishStatus("Schrift wird lokal erkannt …")
        recognitionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.recognitionTask = nil
                self.isRefining = false
                self.publishStatus()
            }
            do {
                let words = try await self.recognition.recognize(
                    image: snapshot.image, crop: snapshot.crop
                )
                try Task.checkCancellation()
                guard self.store.revision == snapshot.revision, self.activeStroke == nil,
                    self.lineMorph == nil,
                    let target = HandwritingComposer.compose(words: words, source: snapshot.source)
                else { return }
                if UIAccessibility.isReduceMotionEnabled {
                    self.store.replace(ids: snapshot.ids, with: target)
                    self.publishStatus("Schrift verfeinert · Zum Widerrufen tippen")
                } else if let morph = LineMorph(
                    ids: snapshot.ids, source: snapshot.source, target: target,
                    now: CACurrentMediaTime()
                ) {
                    self.store.setHidden(snapshot.ids, hidden: true)
                    self.lineMorph = morph
                    self.startDisplayLink()
                    self.redrawLiveLayer()
                }
            } catch is CancellationError {
                return
            } catch {
                // Uncertain ink is deliberately left untouched.
                self.publishStatus("Handschrift bleibt unverändert · Weiter schreiben")
            }
        }
    }

    // MARK: - Animation

    private func startDisplayLink() {
        guard displayLink == nil, window != nil else { return }
        let link = CADisplayLink(
            target: displayLinkProxy, selector: #selector(DisplayLinkProxy.step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLinkProxy.displayLink = link
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
            let preview = engine.preview(stroke.inputs + stroke.predictedInputs)
            if !preview.isEmpty {
                stroke.display = preview
                needsRedraw = true
            }
        }
        var stillMorphing: [LiveStroke] = []
        for stroke in morphingStrokes {
            if stroke.advance(now: now) { needsRedraw = true }
            if stroke.isSettled { commit(stroke) } else { stillMorphing.append(stroke) }
        }
        if stillMorphing.count != morphingStrokes.count {
            morphingStrokes = stillMorphing
            needsRedraw = true
        }
        if let morph = lineMorph {
            if morph.advance(now: now) { needsRedraw = true }
            if morph.isSettled {
                store.setHidden(morph.ids, hidden: false)
                store.replace(ids: morph.ids, with: morph.target)
                lineMorph = nil
                needsRedraw = true
                publishStatus("Schrift verfeinert · Drei Finger tippen zum Widerrufen")
            }
        }
        if needsRedraw { redrawLiveLayer() }
        if activeStroke == nil && morphingStrokes.isEmpty && lineMorph == nil { stopDisplayLink() }
    }

    private func redrawLiveLayer() {
        var visible: [[InkPoint]] = []
        if let stroke = activeStroke, !stroke.display.isEmpty { visible.append(stroke.display) }
        for stroke in morphingStrokes where !stroke.display.isEmpty {
            visible.append(stroke.display)
        }
        if let lineMorph { visible.append(contentsOf: lineMorph.visible) }
        let box = InkRibbon.unionBounds(visible)
        guard !visible.isEmpty, box.width > 0.5 || box.height > 0.5 else {
            liveLayer.path = nil
            return
        }
        let path = CGMutablePath()
        for stroke in visible { InkRibbon.append(to: path, points: stroke, origin: box.origin) }
        liveLayer.bounds = CGRect(origin: .zero, size: box.size)
        liveLayer.position = box.origin
        liveLayer.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
        liveLayer.path = path
    }

    // MARK: - History

    private func cancelLineMorph() {
        if let morph = lineMorph {
            store.setHidden(morph.ids, hidden: false)
            lineMorph = nil
            redrawLiveLayer()
        }
    }

    private func performUndo() {
        cancelRecognition()
        if lineMorph != nil {
            cancelLineMorph()
            publishStatus("Originalschrift wiederhergestellt")
            return
        }
        guard activeStroke == nil else { return }
        if !morphingStrokes.isEmpty {
            morphingStrokes.removeLast()
            redrawLiveLayer()
        } else {
            store.undo()
        }
        publishStatus()
    }

    private func performRedo() {
        cancelRecognition()
        cancelLineMorph()
        guard activeStroke == nil, morphingStrokes.isEmpty else { return }
        store.redo()
        publishStatus()
    }

    private func publishStatus(_ message: String? = nil) {
        controller?.update(
            undo: store.canUndo || lineMorph != nil,
            redo: store.canRedo,
            refining: isRefining || lineMorph != nil,
            status: message
        )
    }

    // MARK: - Finger navigation

    private func applyViewport() {
        inkLayer.setAffineTransform(viewport.transform)
        liveLayer.contentsScale = max(1, traitCollection.displayScale * CGFloat(viewport.scale))
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .changed, activeStroke == nil else { return }
        let translation = recognizer.translation(in: self)
        recognizer.setTranslation(.zero, in: self)
        viewport.pan(dx: Double(translation.x), dy: Double(translation.y))
        applyViewport()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard activeStroke == nil else { return }
        switch recognizer.state {
        case .began:
            pinchStartScale = viewport.scale
        case .changed:
            viewport.setScale(
                pinchStartScale * Double(recognizer.scale), anchor: recognizer.location(in: self)
            )
            applyViewport()
        case .ended, .cancelled, .failed:
            store.refreshContents(displayScale: traitCollection.displayScale, zoom: viewport.scale)
        default: break
        }
    }

    @objc private func handleResetTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, activeStroke == nil else { return }
        viewport.reset()
        applyViewport()
        store.refreshContents(displayScale: traitCollection.displayScale, zoom: viewport.scale)
    }

    @objc private func handleUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        performUndo()
    }

    @objc private func handleRedoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        performRedo()
    }

    // MARK: - Gesture policy

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        InkInputPolicy.acceptsNavigation(Self.kind(of: touch))
    }

    private static func kind(of touch: UITouch) -> InkTouchKind {
        switch touch.type {
        case .pencil: return .pencil
        case .direct: return .finger
        default: return .other
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Palm rejection: a resting hand cannot start navigation mid-stroke.
        activeStroke == nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
