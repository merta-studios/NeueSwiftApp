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
# Geprüft wird jede Swift-Datei unter Core/ (auch in Unterordnern) samt der
# Testdatei. Eine neue Datei in Core/ ist damit automatisch Teil der Prüfung –
# es gibt keine Liste, die veralten könnte.
#
# Umgebungsvariablen:
#   SWIFTC           Compiler (Standard: swiftc)
#   CI_SUMMARY_FILE  Datei für die Schritt-Zusammenfassung (optional)

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

# shellcheck source=ci/lib.sh
. ci/lib.sh

compiler="${SWIFTC:-swiftc}"
core_dir="NeueSwiftApp.swiftpm/Core"
summary_file="${CI_SUMMARY_FILE:-}"

mapfile -t sources < <(find "$core_dir" -name '*.swift' | sort)

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
        ci_annotate error "$file" 1 1 "Datei fehlt (Tests/run-core-tests.sh)"
        status=1
    fi
done
if [ "$status" -ne 0 ]; then
    summary_append "- ❌ App-Logik: gepflegte Dateiliste passt nicht zum Repository"
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
                ci_annotate error "$file" 1 1 "Import '$module' ist in Core/ nicht plattformunabhängig."
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

if ! typecheck_output="$("$compiler" -typecheck "${sources[@]}" "${tests[@]}" 2>&1)"; then
    err "Typ-Prüfung fehlgeschlagen."
    ci_report_swift_output "$typecheck_output"
    summary_append "- ❌ App-Logik: Typ-Prüfung fehlgeschlagen"
    exit 1
fi
ok "Typ-Prüfung bestanden"

# Swift Playgrounds 4.7 bringt Swift 6 mit. Zusätzlich zum normalen Build muss
# der plattformunabhängige Kern auch im Swift-6-Sprachmodus typkorrekt sein
# (strenge Nebenläufigkeit, Sendable-Prüfung statischer Tabellen).
if ! swift6_output="$("$compiler" -swift-version 6 -typecheck "${sources[@]}" 2>&1)"; then
    err "Typ-Prüfung im Swift-6-Sprachmodus fehlgeschlagen."
    ci_report_swift_output "$swift6_output"
    summary_append "- ❌ App-Logik: Swift-6-Typ-Prüfung fehlgeschlagen"
    exit 1
fi
ok "Swift-6-Typ-Prüfung bestanden"

# ---------------------------------------------------------------- Tests bauen

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/neueswiftapp-core-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

binary="$build_dir/core-tests"
if ! build_output="$("$compiler" -O "${sources[@]}" "${tests[@]}" -o "$binary" 2>&1)"; then
    err "Test-Binary ließ sich nicht bauen."
    ci_report_swift_output "$build_output"
    summary_append "- ❌ App-Logik: Test-Binary nicht gebaut"
    exit 1
fi

# ------------------------------------------------------------------ Tests laufen

test_output="$(NEUESWIFT_ROOT="$PWD" "$binary" 2>&1)"
test_rc=$?
printf '%s\n' "$test_output" | sed 's/^/  /'

if [ "$test_rc" -ne 0 ]; then
    err "Tests fehlgeschlagen."
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            "  ✗ "*)
                message="${line#  ✗ }"
                file="${message%%:*}"
                rest="${message#*:}"
                lineno="${rest%%:*}"
                ci_annotate error "$file" "${lineno:-1}" 1 "${rest#*:}"
                ;;
        esac
    done <<<"$test_output"
    ci_annotate error "Tests/CoreTests/main.swift" 1 1 "Ausgabe: $(printf '%s' "$test_output" | tail -n 5 | tr '\n' ' ')"
    summary_append "- ❌ App-Logik: Tests fehlgeschlagen"
    exit 1
fi

ok "Regressionstests der App-Logik bestanden"
summary_append "- ✅ App-Logik: Typ-Prüfung (inkl. Swift 6) und Regressionstests bestanden"
exit 0
