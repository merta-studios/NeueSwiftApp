# Mitarbeiten – prüfen, mergen, IPA bauen

Dieses Repository prüft Änderungen automatisch und mergt sie nach grünen
Pflichtprüfungen in `main`. Kurzfassung für Sessions:
[AGENTS.md](AGENTS.md).

## Ablauf einer Änderung

```
Push auf arena/**, ai/** oder agent/**
        │
        ├─► Auto-Merge legt den Pull Request an (…/auto-merge.yml)
        │
        ├─► Swift-Code-Prüfung startet (…/build-check.yml)
        │     1. Syntax        – jede .swift-Datei wird geparst
        │     2. App-Logik     – Typ-Prüfung + Tests des plattformunabhängigen Codes
        │     3. Format        – swift-format
        │     4. Skripte       – Shell-/Workflow-Prüfung + Auto-Merge-Tests
        │     5. iOS-Build     – Xcode-Build mit iOS-SDK, Start im Simulator
        │
        ├─► alles grün  → Merge-Commit nach main
        │   etwas rot   → Kommentar am PR, kein Merge
        │
        └─► IPA-Build auf main → Artefakt „NeueSwiftApp-unsignierte-IPA“
```

## Die Prüfungen im Einzelnen

### 1. Syntax (Linux, Swift-Container)

`ci/swift-check.sh parse` parst jede `.swift`-Datei mit
`swiftc -frontend -parse`. Das funktioniert auch bei `import SwiftUI/UIKit`,
weil beim Parsen keine Module aufgelöst werden, und findet fehlende Klammern,
kaputte Strings und falsche Interpolationen.

Es gibt **keine** Möglichkeit, Syntaxfehler „nur zu melden“: Fehler sind immer
rot. Werden keine Dateien gefunden, ist das ebenfalls ein Fehlschlag.

### 2. App-Logik (Linux, echter Compiler)

`Tests/run-core-tests.sh` übersetzt die plattformunabhängigen Dateien aus
`NeueSwiftApp.swiftpm/Core` wirklich (`swiftc -typecheck`) und führt die
Regressionstests aus `Tests/CoreTests/main.swift` aus. Getestet wird echter
App-Code: Versionsvergleich (`SemanticVersion`) und App-Metadaten
(`AppMetadata`, inklusive Abgleich mit `Package.swift`).

Damit nichts unbemerkt ungeprüft bleibt, schlägt das Skript fehl, wenn in
`Core/` eine Swift-Datei liegt, die nicht in der Dateiliste steht, oder wenn
`Core/` etwas anderes als `Foundation`/`Dispatch` importiert.

### 3. Format (swift-format)

`ci/lint.sh` prüft mit `swift-format lint --strict` (seit Swift 6 Teil der
Toolchain, hier aus `swift:6.2-noble`). Konfiguration: `.swift-format`
(4 Leerzeichen, Zeilenlänge 100). Lokal beheben:
`ci/run-swift.sh ci/lint.sh --fix`.

### 4. Skripte und Workflows

* `ci/check-shell.sh`: `bash -n` plus `shellcheck` (Mindestschwere `warning`).
  In CI ist shellcheck Pflicht; lokal wird ein Fehlen nur gemeldet.
* `ci/check-workflows.sh`: alle `uses:` müssen auf einen Commit-SHA gepinnt
  sein (mit Versionskommentar), dazu `actionlint` (Version 1.7.12, beim
  Selbst-Download per SHA-256 geprüft) und ein YAML-Parsing.
* `Tests/auto-merge.test.sh`: 30 Szenarien für die Auto-Merge-Entscheidungen
  mit einer `gh`-Attrappe (`Tests/stubs/gh`) – ohne Netz, ohne Token, ohne
  echte Merges.

### 5. iOS-Build und Simulator (macOS)

`ci/ios-build-test.sh` wählt über `ci/select-xcode.sh` die neueste stabile
Xcode-Version, ermittelt das Scheme (`ci/detect-scheme.sh`), baut für den
iOS-Simulator, installiert die App, startet sie und prüft, dass der Prozess
läuft (Screenshot als Artefakt).

Kann ein Swift-Playgrounds-Paket (`.swiftpm`) nicht im Simulator gebaut
werden, fällt das Skript auf einen **unsignierten iOS-Device-Build** zurück und
meldet das als Warnung samt Hinweis in der Job-Zusammenfassung. Ein echter
Compilerfehler scheitert in beiden Varianten.

## Lokal prüfen

```sh
ci/run-swift.sh ci/swift-check.sh parse
ci/run-swift.sh Tests/run-core-tests.sh
ci/run-swift.sh ci/lint.sh
ci/check-shell.sh
ci/check-workflows.sh
Tests/auto-merge.test.sh
```

`ci/run-swift.sh` benutzt Docker/Podman mit `swift:6.2-noble`; ohne Container
mit `SWIFT_IMAGE=local` und lokal installiertem Swift. Auf macOS kommen
`ci/select-xcode.sh`, `ci/ios-build-test.sh` und `ci/build-ipa.sh` dazu.

## Auto-Merge

`ci/auto-merge.sh` entscheidet, `auto-merge.yml` ruft es auf.

* **Automatisch gemergt:** Branches `arena/*`, `ai/*`, `agent/*` sowie jeder PR
  mit Label `automerge`.
* **Nie automatisch:** Entwürfe, Konflikte, anderer Zielbranch, Fork-PRs,
  Label `no-automerge`, PRs mit Änderungen an `.github/`, `ci/`, `Tests/`.
* **Pflichtprüfungen:** die fünf Jobs oben. Fehlende, laufende, übersprungene,
  abgebrochene oder fehlgeschlagene Prüfungen gelten als „nicht bestanden“.
* **`/automerge`** als Kommentar (Owner/Member/Collaborator) löst nur eine
  erneute Auswertung aus. Es gibt keinen Force-Merge und keinen Admin-Bypass.
* **Commit-Bindung:** Der Merge geht über die API mit `sha=<geprüfter Commit>`.
  Ändert sich der Head, lehnt GitHub ab.

### Sicherheitsmodell

| Thema | Umsetzung |
| --- | --- |
| PR-Code mit Schreibrechten | kommt nicht vor: `auto-merge.yml` nutzt `pull_request_target` und checkt **den Default-Branch** aus, nie den PR-Head |
| Rechte | `contents: read` als Standard; nur der Merge-Job hat `contents: write`, `pull-requests: write`, `actions: write` |
| `build-check.yml` | `contents: read`, `persist-credentials: false` |
| Aktionen | auf Commit-SHAs gepinnt (geprüft von `ci/check-workflows.sh`) |
| Selbstfreigabe | Änderungen an `.github/`, `ci/`, `Tests/` sind von der Automatik ausgenommen |
| Fork-PRs | werden nicht automergt (Repository-ID muss übereinstimmen) |
| Unbekannte Prüfungen | nur die ausdrücklich benannten Pflichtprüfungen zählen |
| Nicht auswertbar | mehr als 100 Check-Runs auf einem Commit → keine Automatik |

## GitHub-Einstellungen (einmalig)

Alles, was hier steht, kann nur der Repository-Eigentümer mit Admin-Rechten
setzen. Die Arena-Session hat keinen `administration`-Zugriff.

| Einstellung | Ort | Warum |
| --- | --- | --- |
| Actions erlauben | Settings → Actions → General | ohne Actions läuft keine Prüfung |
| „Allow GitHub Actions to create and approve pull requests“ | Settings → Actions → General → Workflow permissions | damit `auto-merge.yml` den PR selbst anlegen darf (sonst legt ihn die Session an) |
| Workflow-Berechtigungen: „Read repository contents“ als Standard | dieselbe Seite | die Workflows setzen ihre Rechte selbst; Standard darf klein bleiben |
| Branch-Schutz/Ruleset für `main`: Pull Request erforderlich, die fünf Prüfungen als *required status checks*, Force-Push und Löschen verbieten | Settings → Rules/Branches | schützt `main` auch außerhalb der Automatik |
| Merge-Methode „Merge commit“ erlauben | Settings → General | die Automatik mergt mit Merge-Commit |

**Wichtig:** Wenn der Schutz eine **Review** verlangt, kann die Automatik nicht
mergen (`GITHUB_TOKEN` darf nicht approven). Dann entweder keine
Review-Pflicht für `main` oder ein eigenes Token als Secret `AUTOMERGE_TOKEN`
hinterlegen. Keine Session fordert solche Tokens im Chat an – das ist eine
Entscheidung des Eigentümers.

### Repository-Variablen (optional, alle mit Standardwert im Workflow)

| Variable | Standard | Wirkung |
| --- | --- | --- |
| `SWIFT_IMAGE` | `swift:6.2-noble` | Swift-Container der Linux-Jobs |
| `XCODE_APP` | neueste stabile Version | z. B. `26.6` oder `/Applications/Xcode_26.6.app` |
| `APP_SCHEME` | automatisch | Xcode-Scheme erzwingen |
| `AUTOMERGE_BRANCHES` | `arena/*,ai/*,agent/*` | welche Branches automatisch gemergt werden |
| `AUTOMERGE_LABEL` | `automerge` | Opt-in-Label für andere Branches |
| `AUTOMERGE_BLOCK_LABEL` | `no-automerge` | Ausschluss-Label |
| `AUTOMERGE_REQUIRED_CHECKS` | die fünf Job-Namen | Pflichtprüfungen (muss zu `build-check.yml` passen) |
| `AUTOMERGE_PROTECTED_PATHS` | `.github/,ci/,Tests/` | Pfade ohne automatischen Merge |
| `AUTOMERGE_TIMEOUT` | `2700` | Sekunden Wartezeit auf Prüfungen |
| `AUTOMERGE_POLL` | `20` | Abfrageintervall |
| `AUTOMERGE_CANCEL_RETRIES` | `2` | Neustarts bei abgebrochenen Prüfungen |
| `AUTOMERGE_DISPATCH_CHECK` | `1` | nach dem Merge Swift-Prüfung auf `main` anstoßen |
| `AUTOMERGE_DISPATCH_BUILD` | `1` | nach dem Merge IPA-Build anstoßen (`0` spart macOS-Minuten) |

Die Workflows reichen diese Variablen ausdrücklich an die Skripte weiter
(`vars.X || 'Standard'`). Wer eine Variable umbenennt, muss Workflow **und**
Skript anpassen; `Tests/auto-merge.test.sh` prüft nur die Liste der
Pflichtprüfungen.

## IPA

`build-ipa.yml` läuft nach jedem Push auf `main` und per *Run workflow*:

1. Xcode auswählen, Scheme ermitteln.
2. Unsignierten Release-Build für `generic/platform=iOS`
   (`CODE_SIGNING_ALLOWED=NO`).
3. Prüfen, dass das Bundle existiert und `Info.plist` vollständig ist.
4. `Payload/<App>.app` packen, `NeueSwiftApp.ipa` und `.sha256` bilden,
   prüfen, dass genau ein App-Bundle mit `Info.plist` in der IPA liegt.
5. Als Artefakt `NeueSwiftApp-unsignierte-IPA` hochladen (60 Tage).

**Die IPA ist unsigniert** und muss vor der Installation signiert werden
(z. B. Sideloadly/AltStore mit eigener Apple-ID). Das passiert bewusst
außerhalb von GitHub – es werden keine Zertifikate, Profile oder
Apple-Zugangsdaten im Repository hinterlegt.

## Fehlersuche

| Symptom | Ursache / Lösung |
| --- | --- |
| Alle Jobs starten mit 0 Schritten, Annotation „recent account payments have failed“ | Actions-Kontingent/Abrechnung. <https://github.com/settings/billing> prüfen. Kein Codefehler. |
| „ausstehend: …“ bis zur Zeitüberschreitung | Eine Pflichtprüfung wurde nie ausgelöst. Meist weil sie umbenannt wurde (dann Skript + Workflow + Job anpassen) oder weil GitHub keine Läufe für `GITHUB_TOKEN`-Ereignisse startet – das Skript stößt den Prüf-Workflow zweimal selbst an. |
| „übersprungen gilt nicht als bestanden“ | Ein Job wurde per `if:`/Bedingung übersprungen. Prüfungen ohne Ergebnis zählen nicht. |
| „abgebrochen, kein Ergebnis“ | Der Lauf wurde abgebrochen (z. B. durch `concurrency`). Nach `AUTOMERGE_CANCEL_RETRIES` Versuchen bleibt der PR offen. |
| „Änderungen an geschützten Pfaden“ | `.github/`, `ci/` oder `Tests/` geändert – bitte von Hand mergen. |
| „Fork-PRs werden nicht automergt“ | gewollt. |
| „Merge fehlgeschlagen: branch protection“ | Review-Pflicht oder weitere Required Checks. Siehe Einstellungen oben. |
| IPA-Build grün, aber keine IPA | Artefakt heißt `NeueSwiftApp-unsignierte-IPA`; Artefakte sind keine Releases, sie liegen unter *Actions → Lauf → Artifacts*. |
| Simulator-Job meldet Warnung „Simulator-Smoke-Test übersprungen“ | Pakettyp ließ den Simulator-Build nicht zu; der unsignierte Device-Build war grün. Dokumentierte Einschränkung. |

## Kosten

Öffentliches Repository: Standard-Runner sind kostenlos. Privates Repository:
macOS zählt **10×** – der iOS-Job je PR und der IPA-Build je Merge sind die
teuersten Posten. `AUTOMERGE_DISPATCH_BUILD=0` halbiert die macOS-Läufe.
