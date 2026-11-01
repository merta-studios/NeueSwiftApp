# NeueSwiftApp

Grundlage für eine App, die in **Swift Playgrounds** auf dem iPad (und in
Xcode) geöffnet und bearbeitet werden kann. Dieses Repository enthält bisher
bewusst **keine App-Funktionen** – nur das App-Paket mit einer
Einstiegsansicht, Prüfungen und Automatisierung.

| | |
| --- | --- |
| App-Paket | `NeueSwiftApp.swiftpm` (SwiftUI, iOS 17) |
| Bundle-ID | `com.example.neueswiftapp` (**Platzhalter**) |
| Anzeigename | `NeueSwiftApp` (**Platzhalter**) |
| Default-Branch | `main` |
| Prüfungen | `.github/workflows/build-check.yml` |
| Auto-Merge | `.github/workflows/auto-merge.yml` + `ci/auto-merge.sh` |
| IPA | `.github/workflows/build-ipa.yml` → Artefakt `NeueSwiftApp-unsignierte-IPA` |

## Projektstruktur

```
NeueSwiftApp.swiftpm/          Swift-Playgrounds-App-Paket
  Package.swift                Manifest (AppleProductTypes, iOS 17)
  App.swift                    @main-Einstieg (SwiftUI)
  Views/ContentView.swift      Einstiegsansicht
  Core/                        plattformunabhängige Logik (nur Foundation)
    AppMetadata.swift          Name, Bundle-ID, Version
    SemanticVersion.swift      Versionsvergleich
  Assets.xcassets/             App-Icon (Platzhalter)
ci/                            Prüf- und Automatisierungsskripte
Tests/                         Logik-Tests und Tests der Auto-Merge-Logik
.github/workflows/             GitHub Actions
AGENTS.md / CONTRIBUTING.md    Ablauf, Einstellungen, Fehlersuche
```

## Lokale Prüfungen

Dieselben Befehle, die auch in GitHub Actions laufen:

```sh
ci/run-swift.sh ci/swift-check.sh parse     # Syntax aller Swift-Dateien
ci/run-swift.sh Tests/run-core-tests.sh     # Typ-Prüfung + Tests der App-Logik
ci/run-swift.sh ci/lint.sh                  # swift-format
ci/check-shell.sh                           # Shell-Skripte (bash -n, shellcheck)
ci/check-workflows.sh                       # Workflows (SHA-Pinning, actionlint, YAML)
Tests/auto-merge.test.sh                    # Auto-Merge-Entscheidungen (ohne Netz)
```

`ci/run-swift.sh` benutzt den offiziellen Container `swift:6.2-noble`
(überschreibbar mit `SWIFT_IMAGE`). Ohne Docker genügt ein lokales Swift mit
`SWIFT_IMAGE=local`. Der iOS-Build braucht macOS mit Xcode:

```sh
ci/select-xcode.sh
ci/ios-build-test.sh        # Build + Start im Simulator
ci/build-ipa.sh             # unsignierte IPA nach build/NeueSwiftApp.ipa
```

## Unterstützte Versionen

| Komponente | Wert | Nachweis |
| --- | --- | --- |
| Swift-Tools (Manifest) | `swift-tools-version: 5.9` (Minimum) | `Package.swift` |
| Swift-Toolchain der Linux-Jobs | 6.2 (`swift:6.2-noble`) | Syntax-, App-Logik- und Format-Job im CI-Lauf |
| iOS-Mindestversion | 17.0 | `Package.swift`, `AppMetadata.minimumIOSVersion` |
| Xcode in CI | **26.6**, iOS-SDK **26.5**, Simulator-Laufzeit **iOS 26.2** | Annotation „macOS-Buildumgebung“ des iOS-Jobs; festlegbar per Repo-Variable `XCODE_APP` |
| Runner | `macos-26` (iOS-Build, IPA), `ubuntu-24.04` (Linux-Prüfungen) | Workflow-Dateien |
| iPadOS / Swift Playgrounds | **nicht verifiziert** | – |

Das Paket hat das Deployment-Target iOS 17 und braucht auf dem iPad daher
iPadOS ≥ 17 sowie eine Swift-Playgrounds-Version, die iOS-17-App-Pakete
unterstützt. Ob es dort tatsächlich geöffnet, bearbeitet und ausgeführt werden
kann, ist **nicht getestet** – dafür ist ein echtes iPad nötig.

## Was tatsächlich geprüft wurde

Stand dieses Branches, alle Jobs des Workflows „Swift-Code-Prüfung“ grün:

| Prüfung | Ergebnis |
| --- | --- |
| `Syntax (alle Swift-Dateien)` | ✅ alle `.swift`-Dateien geparst (Swift 6.2 im Container) |
| `App-Logik (Typen und Tests)` | ✅ echte Typ-Prüfung, 87 Testprüfungen bestanden |
| `swift-format (Format)` | ✅ keine Abweichung von `.swift-format` |
| `Skripte und Workflows (Lint und Tests)` | ✅ 14 Shell-Skripte (shellcheck), Workflows (SHA-Pinning, actionlint 1.7.12, YAML), 30 Auto-Merge-Szenarien |
| `iOS-Build und Simulator-Smoke (Xcode)` | ✅ Build mit iOS-SDK, Installation und Start im Simulator, Screenshot als Artefakt |
| `IPA-Build (unsigniert)` | ✅ in einem einmaligen Testlauf auf dem PR: `Payload/NeueSwiftApp.app`, Artefakt `NeueSwiftApp-unsignierte-IPA` (~60 KB) |

**Nicht geprüft:** Swift Playgrounds auf dem iPad, echtes Gerät, Signierung,
App-Store-Upload. Ein Linux-Syntaxcheck und ein erfolgreicher CI-Build ersetzen
keinen Test auf echter Hardware.

## Auto-Merge in Kurzform

Ein Push auf `arena/**`, `ai/**` oder `agent/**` erzeugt automatisch einen
Pull Request; nach grünen Pflichtprüfungen wird er nach `main` gemergt.
Danach entsteht die unsignierte IPA. Änderungen an `.github/`, `ci/` und
`Tests/` werden **nie** automatisch gemergt, und es gibt keinen Schalter, der
Prüfungen überspringt. Details: [AGENTS.md](AGENTS.md),
[CONTRIBUTING.md](CONTRIBUTING.md).

## IPA

Die IPA ist **unsigniert** und lässt sich nicht direkt installieren. Sie muss
mit einer eigenen Apple-ID signiert werden (z. B. Sideloadly, AltStore). Es
werden keine Apple-Zugangsdaten, Zertifikate oder Tokens in diesem Repository
oder in GitHub hinterlegt – und niemand muss sie im Chat weitergeben.
