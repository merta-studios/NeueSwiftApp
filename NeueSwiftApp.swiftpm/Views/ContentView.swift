import SwiftUI

/// Einstiegsansicht der Projektgrundlage: zeigt nur die App-Metadaten.
/// Bewusst ohne App-Funktionen – die kommen in späteren Schritten.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(AppMetadata.displayName)
                    .font(.largeTitle.bold())
                Text(AppMetadata.aboutLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                metadataRow(title: "Bundle-ID", value: AppMetadata.bundleIdentifier)
                metadataRow(title: "Mindest-iOS", value: AppMetadata.minimumIOSVersion)
            }
            .frame(maxWidth: 420, alignment: .leading)

            if AppMetadata.isPlaceholderBundleIdentifier
                || !AppMetadata.isValidBundleIdentifier(AppMetadata.bundleIdentifier)
            {
                Text(
                    "Platzhalter: App-Name und Bundle-ID vor dem ersten Release "
                        + "in Package.swift und AppMetadata.swift ersetzen."
                )
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            }

            Text("Projektgrundlage – noch keine App-Funktionen.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
    }
}

#Preview {
    ContentView()
}
