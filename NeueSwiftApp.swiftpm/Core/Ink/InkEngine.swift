import Foundation

/// Verbindet Stift-Eingabe, Beautifier und Lernen.
///
/// Die Engine ist das Gedächtnis der App: Sie hält das gelernte Schreibprofil
/// und den gelernten Glättungskern, liefert die Live-Linie während des
/// Schreibens und die schöne Linie nach dem Abheben des Stifts. Sie kennt kein
/// UIKit – dieselbe Klasse läuft in der App und in den Tests unter Linux.
final class InkEngine {
    private(set) var style: WritingStyle
    private(set) var kernel: LearnedSmoothingKernel
    private(set) var finishedStrokes: Int = 0

    private let beautifier: StrokeBeautifier

    init(style: WritingStyle = WritingStyle(), kernel: LearnedSmoothingKernel = .prior()) {
        self.style = style
        self.kernel = kernel
        self.beautifier = StrokeBeautifier()
    }

    /// Linie, die während des Schreibens gezeichnet wird.
    func preview(_ inputs: [InkInput]) -> [InkPoint] {
        beautifier.preview(inputs, style: style, kernel: kernel)
    }

    /// Fertige, aufbereitete Linie – und Anlass, das Profil nachzuführen.
    func finish(_ inputs: [InkInput]) -> [InkPoint] {
        let beautified = beautifier.beautify(inputs, style: style, kernel: kernel)
        learn(from: inputs, beautified: beautified)
        finishedStrokes += 1
        return beautified
    }

    func reset() {
        style.reset()
        kernel.reset()
        finishedStrokes = 0
    }

    // MARK: - Lernen

    private func learn(from inputs: [InkInput], beautified: [InkPoint]) {
        let prepared = beautifier.prepare(inputs, style: style)
        let raw = prepared.trace.points
        guard raw.count >= 3, beautified.count >= 3 else { return }

        // 1) Glättungskern: rohe Linie → schöne Linie.
        let alignedRaw = PolylineGeometry.resample(raw, count: beautified.count)
        let targets = beautified.map { $0.position }
        kernel.learn(raw: alignedRaw, target: targets)

        // 2) Profil: Zittern, Neigung, Druck, Tempo.
        let tremorX = SignalFilters.highFrequencyEnergy(raw.map { $0.x })
        let tremorY = SignalFilters.highFrequencyEnergy(raw.map { $0.y })
        let tremor = (tremorX * tremorX + tremorY * tremorY).squareRoot()
        let slant = StrokeBeautifier.slant(of: beautified)

        style.observe(
            tremor: tremor,
            slant: slant,
            peakPressure: prepared.peakPressure,
            hasPressure: prepared.hasPressure,
            medianSpeed: prepared.medianSpeed
        )
    }
}
