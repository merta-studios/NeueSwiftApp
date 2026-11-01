#!/usr/bin/env bash
#
# Tests/run-core-tests.sh – Typ-Prüfung und Regressionstests der
# plattformunabhängigen App-Logik mit echtem Swift-Compiler.
#
#   Tests/run-core-tests.sh
#
# Läuft unter Linux (Swift-Container) und unter macOS gleich. Geprüft wird
# echter Code aus NeueSwiftApp.swiftpm/Core – derselbe Code, den die App
# benutzt. Kein iOS-SDK nötig, aber auch keine Ausrede: ein Compilerfehler ist
# hier ein Fehlschlag.
#
# Die Dateiliste ist bewusst explizit: nur so ist garantiert, dass nichts
# iOS-Abhängiges mitgezogen wird. Damit die Liste nicht veraltet, schlägt das
# Skript fehl, sobald in Core/ eine Swift-Datei liegt, die nicht aufgeführt ist.
#
# Umgebungsvariablen:
#   SWIFTC           Compiler (Standard: swiftc)
#   CI_SUMMARY_FILE  Datei für die Schritt-Zusammenfassung (optional)

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

compiler="${SWIFTC:-swiftc}"
core_dir="NeueSwiftApp.swiftpm/Core"
summary_file="${CI_SUMMARY_FILE:-}"

sources=(
    "$core_dir/AppMetadata.swift"
    "$core_dir/SemanticVersion.swift"
)
tests=(
    "Tests/CoreTests/main.swift"
)

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

summary_append() {
    [ -n "$summary_file" ] || return 0
    printf '%s\n' "$1" >>"$summary_file"
}

if ! command -v "$compiler" >/dev/null 2>&1; then
    echo "Swift-Compiler '$compiler' fehlt. Über ci/run-swift.sh starten (Container)." >&2
    exit 127
fi

log "App-Logik unter Linux: Typ-Prüfung und Tests"
note "Compiler: $("$compiler" --version 2>&1 | head -n 1)"

# ---------------------------------------------------------------- Dateilisten

status=0
for file in "${sources[@]}" "${tests[@]}"; do
    if [ ! -f "$file" ]; then
        err "Datei fehlt: $file"
        status=1
    fi
done
if [ "$status" -ne 0 ]; then
    summary_append "- ❌ App-Logik: gepflegte Dateiliste passt nicht zum Repository"
    exit 1
fi

# Core/ muss vollständig in der Liste stehen – sonst würde neuer Code
# ungeprüft bleiben.
missing=0
while IFS= read -r file; do
    found=0
    for listed in "${sources[@]}"; do
        [ "$listed" = "$file" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
        err "$file steht nicht in der Dateiliste von Tests/run-core-tests.sh"
        missing=$((missing + 1))
    fi
done < <(find "$core_dir" -name '*.swift' | sort)

if [ "$missing" -gt 0 ]; then
    note "Neue Datei in $core_dir? Dann dort ergänzen und erneut prüfen."
    summary_append "- ❌ App-Logik: $missing Datei(en) in Core/ nicht abgedeckt"
    exit 1
fi

# Core/ darf nur plattformunabhängige Module importieren.
portable_violations=0
while IFS= read -r file; do
    while IFS= read -r module; do
        [ -n "$module" ] || continue
        case "$module" in
            Foundation | Dispatch | FoundationEssentials | Glibc | Darwin) ;;
            *)
                err "$file importiert '$module' – Core/ muss plattformunabhängig bleiben."
                portable_violations=$((portable_violations + 1))
                ;;
        esac
    done < <(sed -nE 's/^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' "$file")
done < <(find "$core_dir" -name '*.swift' | sort)

if [ "$portable_violations" -gt 0 ]; then
    summary_append "- ❌ App-Logik: $portable_violations iOS-Import(e) in Core/"
    exit 1
fi

ok "${#sources[@]} App-Datei(en) und ${#tests[@]} Testdatei(en) gefunden"

# ------------------------------------------------------------- Typ-Prüfung

if ! "$compiler" -typecheck "${sources[@]}" "${tests[@]}"; then
    err "Typ-Prüfung fehlgeschlagen."
    summary_append "- ❌ App-Logik: Typ-Prüfung fehlgeschlagen"
    exit 1
fi
ok "Typ-Prüfung bestanden"

# ---------------------------------------------------------------- Tests bauen

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/neueswiftapp-core-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

binary="$build_dir/core-tests"
if ! "$compiler" -O "${sources[@]}" "${tests[@]}" -o "$binary"; then
    err "Test-Binary ließ sich nicht bauen."
    summary_append "- ❌ App-Logik: Test-Binary nicht gebaut"
    exit 1
fi

# ------------------------------------------------------------------ Tests laufen

if ! NEUESWIFT_ROOT="$PWD" "$binary"; then
    err "Tests fehlgeschlagen."
    summary_append "- ❌ App-Logik: Tests fehlgeschlagen"
    exit 1
fi

ok "Regressionstests der App-Logik bestanden"
summary_append "- ✅ App-Logik: Typ-Prüfung und Regressionstests bestanden"
exit 0
