#!/usr/bin/env bash
#
# ci/lint.sh – Format-Prüfung mit swift-format (Teil der Swift-Toolchain seit
# Swift 6, hier aus dem offiziellen Container). Ohne Abweichung vom
# Formatierstandard ist die Prüfung grün; es wird nichts stillschweigend
# übersprungen.
#
#   ci/lint.sh              # prüfen
#   ci/lint.sh --fix        # lokal formatieren (schreibt Dateien)
#
# Umgebungsvariablen:
#   CI_SUMMARY_FILE  Datei für die Schritt-Zusammenfassung (optional)
#
# Ist swift-format nicht vorhanden, endet das Skript mit Fehler (Code 127) –
# die gewählte Toolchain enthält es, ein stiller Skip wäre also irreführend.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

summary_file="${CI_SUMMARY_FILE:-}"
paths=(NeueSwiftApp.swiftpm Tests/CoreTests)
mode="lint"

if [ "${1:-}" = "--fix" ]; then
    mode="format"
fi

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

summary_append() {
    [ -n "$summary_file" ] || return 0
    printf '%s\n' "$1" >>"$summary_file"
}

formatter=()
if command -v swift-format >/dev/null 2>&1; then
    formatter=(swift-format)
elif command -v swift >/dev/null 2>&1 && swift format --version >/dev/null 2>&1; then
    formatter=(swift format)
fi

if [ "${#formatter[@]}" -eq 0 ]; then
    err "swift-format nicht gefunden (gehört seit Swift 6 zur Toolchain)."
    note "In GitHub Actions läuft die Prüfung im Container swift:6.2-noble."
    summary_append "- ❌ swift-format: Werkzeug nicht verfügbar"
    exit 127
fi

files=$(find "${paths[@]}" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
if [ "$files" -eq 0 ]; then
    err "Keine Swift-Datei zum Prüfen gefunden – das ist kein Erfolg."
    summary_append "- ❌ swift-format: keine Datei geprüft"
    exit 1
fi

log "swift-format: $files Datei(en) in ${paths[*]}"
note "Version: $("${formatter[@]}" --version 2>&1 | head -n 1)"
note "Konfiguration: .swift-format (4 Leerzeichen, Zeilenlänge 100)"

if [ "$mode" = "format" ]; then
    "${formatter[@]}" format --in-place --recursive "${paths[@]}"
    ok "Dateien formatiert. Bitte Änderungen prüfen und committen."
    summary_append "- ℹ️ swift-format: Dateien neu formatiert (lokaler Lauf)"
    exit 0
fi

status=0
if ! "${formatter[@]}" lint --strict --recursive "${paths[@]}"; then
    status=1
    echo
    err "Format-Abweichungen gefunden."
    note "Lokal beheben: ci/run-swift.sh ci/lint.sh --fix"
    summary_append "- ❌ swift-format: $files Datei(en) geprüft, Abweichungen gefunden"
else
    ok "Alle $files Datei(en) sind korrekt formatiert."
    summary_append "- ✅ swift-format: $files Datei(en) ohne Abweichung"
fi

exit "$status"
