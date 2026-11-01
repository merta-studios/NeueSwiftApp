import SwiftUI

/// Die App ist eine Schreibfläche.
///
/// Bewusst ohne Hauptmenü, ohne Werkzeugleiste und ohne Speichern: App öffnen,
/// mit dem Apple Pencil schreiben, mit zwei Fingern zoomen und verschieben.
/// Alles andere übernimmt die Tinten-Engine im Hintergrund.
struct ContentView: View {
    var body: some View {
        InkCanvas()
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
