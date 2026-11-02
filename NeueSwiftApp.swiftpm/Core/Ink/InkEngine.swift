import Foundation

/// Verbindet Stift-Eingabe, Beautifier und Lernen.
///
/// Die Engine ist das Gedächtnis der App: Sie hält das gelernte Schreibprofil,
/// liefert die Live-Linie während des Schreibens und die schöne Linie nach dem
/// Abheben des Stifts. Sie kennt kein UIKit – dieselbe Klasse läuft in der App
/// und in den Tests unter Linux.
final class InkEngine {
    private(set) var style: WritingStyle
    private(set) var finishedStrokes: Int = 0

    private let beautifier: StrokeBeautifier

    init(style: WritingStyle = WritingStyle()) {
        self.style = style
        self.beautifier = StrokeBeautifier()
    }

    /// Linie, die während des Schreibens gezeichnet wird.
    func preview(_ inputs: [InkInput]) -> [InkPoint] {
        beautifier.preview(inputs, style: style)
    }

    /// Fertige, aufbereitete Linie – und Anlass, das Profil nachzuführen.
    func finish(_ inputs: [InkInput]) -> [InkPoint] {
        let beautified = beautifier.beautify(inputs, style: style)
        learn(from: inputs, beautified: beautified)
        finishedStrokes += 1
        return beautified
    }

    func reset() {
        style.reset()
        finishedStrokes = 0
    }

    // MARK: - Lernen

    private func learn(from inputs: [InkInput], beautified: [InkPoint]) {
        let prepared = beautifier.prepare(inputs, style: style)
        let raw = prepared.trace.points
        guard raw.count >= 3, beautified.count >= 3 else { return }

        // Profil: Zittern, Neigung, Druck, Tempo. Das Zittern wird auf einer
        // gleichmäßig abgetasteten Reihe gemessen; sonst hängt der Wert am
        // Schreibtempo statt an der Hand.
        let uniform = PolylineGeometry.resample(prepared.trace, spacing: beautifier.spacing)
        let tremorSource = uniform.count >= 4 ? uniform.points : raw
        let tremorX = SignalFilters.highFrequencyEnergy(tremorSource.map { $0.x })
        let tremorY = SignalFilters.highFrequencyEnergy(tremorSource.map { $0.y })
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
