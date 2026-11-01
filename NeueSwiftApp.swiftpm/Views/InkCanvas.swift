import SwiftUI

/// SwiftUI-Verpackung für den Schreibbereich.
///
/// Der Schreibbereich ist eine UIKit-Ansicht, weil Stift-Eingabe mit
/// `coalescedTouches` und ein `CADisplayLink` für die Linien-Animation dort
/// direkt verfügbar sind. Nach außen ist das ein einziges View ohne Parameter –
/// kein Menü, keine Werkzeugleiste, kein Speichern.
struct InkCanvas: UIViewRepresentable {
    func makeUIView(context: Context) -> InkCanvasView {
        InkCanvasView()
    }

    func updateUIView(_ uiView: InkCanvasView, context: Context) {}
}
