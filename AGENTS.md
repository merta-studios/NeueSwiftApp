# AGENTS.md – Hinweise für automatisch arbeitende Sessions

Kurz und praktisch. Ausführlicher für Menschen: [CONTRIBUTING.md](CONTRIBUTING.md).
Projektüberblick: [README.md](README.md).

## Grundregeln

1. **Nur auf dem eigenen Branch arbeiten** (`arena/<session>-neueswiftapp`,
   `ai/*`, `agent/*`). `main` nie direkt beschreiben, nie umschreiben
   (kein Force-Push, kein Rebase von `main`).
2. **Kein Pull Request von Hand nötig.** Ein Push auf `arena/**` erzeugt den
   PR automatisch (`auto-merge.yml` → `ci/auto-merge.sh`), sobald die
   Automatik auf `main` liegt.
3. **Nichts erzwingen.** Es gibt keinen Admin-Bypass und keinen Schalter, der
   Prüfungen überspringt. Rote, fehlende, abgebrochene oder übersprungene
   Prüfungen bedeuten: Ursache beheben und erneut pushen.
4. **Keine Apple-Zugangsdaten, Zertifikate oder Tokens** anfordern oder
   hinterlegen. Die IPA wird unsigniert gebaut; signiert wird außerhalb.
5. Nicht behaupten, etwas sei auf dem iPad oder in Swift Playgrounds getestet,
   solange das nicht tatsächlich passiert ist.

## Prüfungen, die den Merge blockieren

Alle fünf Jobs aus `.github/workflows/build-check.yml` sind Pflicht:

| Job-Name (exakt) | Inhalt | Läuft auf |
| --- | --- | --- |
| `Syntax (alle Swift-Dateien)` | `swiftc -frontend -parse` über jede `.swift`-Datei, auch SwiftUI/UIKit | Linux + Swift-Container |
| `App-Logik (Typen und Tests)` | `Tests/run-core-tests.sh`: echte Typ-Prüfung und Tests von `NeueSwiftApp.swiftpm/Core` | Linux + Swift-Container |
| `swift-format (Format)` | `ci/lint.sh` (Swift 6 Toolchain) | Linux + Swift-Container |
| `Skripte und Workflows (Lint und Tests)` | `ci/check-shell.sh`, `ci/check-workflows.sh`, `Tests/auto-merge.test.sh` | Linux |
| `iOS-Build und Simulator-Smoke (Xcode)` | echter Build mit iOS-SDK, Installation und Start im Simulator | macOS 26 |

Die Liste steht an drei Stellen und wird von `Tests/auto-merge.test.sh`
gegeneinander geprüft: Standard in `ci/auto-merge.sh`, Vorgabe in
`auto-merge.yml` und die Job-Namen in `build-check.yml`. Wer einen Job
umbenennt, muss alle drei Stellen anpassen – sonst blockiert der Auto-Merge
jeden PR mit „ausstehend“.

## Lokal prüfen (vor jedem Push)

```sh
ci/run-swift.sh ci/swift-check.sh parse     # Syntax
ci/run-swift.sh Tests/run-core-tests.sh     # Typ-Prüfung + Logik-Tests
ci/run-swift.sh ci/lint.sh                  # Format (--fix formatiert)
ci/check-shell.sh                           # Shell-Skripte
ci/check-workflows.sh                       # Workflows
Tests/auto-merge.test.sh                    # Auto-Merge-Logik, ohne Netz
```

`ci/run-swift.sh` braucht Docker/Podman oder lokal installiertes Swift
(`SWIFT_IMAGE=local`). Fehlt beides, ist GitHub Actions die Prüfinstanz:

```sh
gh run list --limit 10
gh run watch <id>
gh api repos/<owner>/<repo>/actions/runs/<id>/jobs \
  --jq '.jobs[] | [.name, (.conclusion // "?"), (.steps|length)] | @tsv'
gh api repos/<owner>/<repo>/commits/<sha>/check-runs \
  --jq '.check_runs[] | [.name, (.status), (.conclusion // "?")] | @tsv'
```

Vollständige Log-Downloads sind in Sandboxes oft gesperrt; Jobs, Schritte und
Check-Run-Annotationen liefern trotzdem das Ergebnis:

```sh
gh api repos/<owner>/<repo>/check-runs/<id>/annotations --jq '.[].message'
```

## Auto-Merge: was passiert wann

| Auslöser | Verhalten |
| --- | --- |
| Push auf `arena/**`, `ai/**`, `agent/**` | PR anlegen (falls keiner existiert) und nach grünen Prüfungen mergen |
| PR geöffnet/aktualisiert/labeled/`ready_for_review` | Prüfungen abwarten, dann mergen |
| Prüfung abgeschlossen (`workflow_run`) | erneut auswerten |
| Kommentar `/automerge` (Owner/Member/Collaborator) | **nur erneute Auswertung**, keine Umgehung |
| Manuell (`Run workflow`, `-f pr=…`, `-f dry_run=true`) | derselbe Ablauf zum Nachsehen |

Nicht gemergt werden: Entwürfe, Konflikte (`mergeable: false`), anderer
Zielbranch als der Default-Branch, Fork-PRs (auch bei gleichem Branch-Namen),
PRs mit Label `no-automerge`, PRs ohne passenden Branch-Namen und ohne Label
`automerge`.

**Geschützte Pfade:** Ändert ein PR Dateien unter `.github/`, `ci/` oder
`Tests/`, verweigert die Automatik den Merge (Kommentar am PR). Solche
Änderungen können die Prüfungen selbst beeinflussen und müssen von einem
Menschen angesehen und gemergt werden. Für eine Agent-Session heißt das:
Änderung umsetzen, PR offen lassen, im Ergebnis klar sagen, dass ein manueller
Merge nötig ist.

**Commit-Bindung:** Gemergt wird über die Merge-API mit `sha=<geprüfter
Head-Commit>`. Ändert sich der Head zwischen Prüfung und Merge, lehnt GitHub ab
und das Skript bricht ab.

**Nach dem Merge:** Ein Merge mit `GITHUB_TOKEN` löst selbst keine Workflows
aus. Deshalb stößt das Skript die Swift-Prüfung und den IPA-Build auf dem
Default-Branch ausdrücklich an – aber nur, wenn für den Merge-Commit noch kein
Lauf existiert (`actions/runs?head_sha=…`), damit nichts doppelt läuft.

## Was dieses Repository (noch) nicht automatisch kann

* **Erster Durchlauf:** Solange `ci/auto-merge.sh` nicht auf `main` liegt,
  überspringt der Auto-Merge-Job sich selbst (Checkout des Default-Branch!).
  Der erste PR muss von Hand gemergt werden. Danach greift die Automatik.
* **Branch-Schutz:** Kann nur von jemandem mit Admin-Rechten eingerichtet
  werden (siehe Checkliste in CONTRIBUTING.md). Verlangt der Schutz eine
  Review, kann die Automatik mit `GITHUB_TOKEN` nicht mergen – dann entweder
  die Review-Pflicht für `main` weglassen oder ein eigenes Token als Secret
  `AUTOMERGE_TOKEN` hinterlegen (Entscheidung des Repository-Eigentümers, nicht
  der Session).
* **Fork-PRs:** werden nie automatisch gemergt.
* **Swift Playgrounds / iPad:** wird hier nicht getestet.

## Wenn GitHub Actions nicht startet

Symptom: Lauf nach Sekunden rot, alle Jobs mit 0 Schritten, Annotation
„The job was not started because recent account payments have failed …“.
Dann ist das Actions-Kontingent bzw. die Abrechnung das Problem, nicht der
Code:

```sh
gh api repos/<owner>/<repo>/actions/runs/<id>/jobs --jq '.jobs[] | [.name, (.steps|length)] | @tsv'
gh api repos/<owner>/<repo>/check-runs/<id>/annotations --jq '.[].message'
```

Nicht endlos warten, sondern dem Menschen melden (Abrechnung/Kontingent prüfen)
und keine Prüfungen „überspringen“.

## Artefakte

| Artefakt | Inhalt | Aufbewahrung |
| --- | --- | --- |
| `NeueSwiftApp-unsignierte-IPA` | `NeueSwiftApp.ipa` + `.sha256` | 60 Tage |
| `ios-simulator-screenshot` | Screenshot des Simulator-Starts | 14 Tage |
| `ios-build-log`, `ipa-build-log` | `xcodebuild`-Protokolle bei Fehlschlag | 14 Tage |

Die IPA muss vor der Installation signiert werden (eigene Apple-ID, z. B.
Sideloadly/AltStore).

## Kosten

Das Repository ist öffentlich; GitHub Actions auf Standard-Runnern ist dafür
kostenlos. Bei einem **privaten** Repository zählt der macOS-Runner das
**Zehnfache** an Minuten: Der Job `iOS-Build und Simulator-Smoke` läuft bei
jedem PR (typisch 5–8 Minuten → 50–80 „Minuten“), der IPA-Build nach jedem
Merge (typisch 3–5 Minuten → 30–50 „Minuten“). Wer sparen will:
`AUTOMERGE_DISPATCH_BUILD=0` setzen (IPA nur noch manuell starten) und den
macOS-Job seltener laufen lassen – aber **nicht** aus der Pflichtliste nehmen,
ohne das hier zu dokumentieren.
