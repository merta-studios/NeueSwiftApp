import SwiftUI

/// SwiftUI-Verpackung für das eigene UIKit-Canvas (kein PencilKit).
struct InkCanvas: UIViewRepresentable {
    let controller: InkCanvasController

    func makeUIView(context: Context) -> InkCanvasView {
        let view = InkCanvasView()
        view.controller = controller
        return view
    }

    func updateUIView(_ uiView: InkCanvasView, context: Context) {
        uiView.controller = controller
    }
}
