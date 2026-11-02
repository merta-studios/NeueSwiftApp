import SwiftUI

/// Die Schreibfläche bleibt im Mittelpunkt; nur eine kleine, erreichbare Leiste
/// für Verlauf und Schrifterkennung liegt darüber.
struct ContentView: View {
    @StateObject private var controller = InkCanvasController()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            InkCanvas(controller: controller)
                .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 8) {
                Text(controller.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityHidden(true)

                HStack(spacing: 4) {
                    Button {
                        controller.onUndo?()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 40, height: 40)
                    }
                    .disabled(!controller.canUndo)
                    .accessibilityLabel("Widerrufen")

                    Button {
                        controller.onRedo?()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .frame(width: 40, height: 40)
                    }
                    .disabled(!controller.canRedo)
                    .accessibilityLabel("Wiederholen")

                    Menu {
                        Toggle("Schrift automatisch verfeinern", isOn: $controller.refinementEnabled)
                        Button {
                            controller.onRefine?()
                        } label: {
                            Label("Letzte Zeile jetzt verfeinern", systemImage: "sparkles")
                        }
                        .disabled(controller.isRefining)
                    } label: {
                        Image(systemName: controller.isRefining ? "ellipsis" : "sparkles")
                            .frame(width: 44, height: 40)
                    }
                    .accessibilityLabel("Schriftkorrektur")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(20)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
