#!/usr/bin/env bash
#
# ci/run-swift.sh – führt einen Befehl in einem Linux-Container mit
# installiertem Swift aus. Damit laufen Syntax-Prüfung, Logik-Tests und
# swift-format lokal und in GitHub Actions mit derselben Toolchain.
#
#   ci/run-swift.sh swift --version
#   ci/run-swift.sh ci/swift-check.sh parse
#   ci/run-swift.sh Tests/run-core-tests.sh
#   ci/run-swift.sh ci/lint.sh
#
# Ohne Container-Laufzeit (oder mit SWIFT_IMAGE=local) wird der Befehl direkt
# ausgeführt; dann muss Swift lokal installiert sein.
#
# Umgebungsvariablen:
#   SWIFT_IMAGE   Container-Image (Standard: swift:6.2-noble, "local" = keins)
#   SWIFT_BIN     Compiler für den lokalen Fall (Standard: swift)
#   CI_SUMMARY    Sammeldatei für die Schritt-Zusammenfassung

set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -eq 0 ]; then
    echo "Aufruf: ci/run-swift.sh <befehl> [argumente...]" >&2
    exit 2
fi

image="${SWIFT_IMAGE:-swift:6.2-noble}"
summary=".ci-summary.md"
rm -f "$summary"

append_summary() {
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f "$summary" ]; then
        cat "$summary" >>"$GITHUB_STEP_SUMMARY"
    fi
    rm -f "$summary"
}

container=""
if [ "$image" != "local" ]; then
    if command -v docker >/dev/null 2>&1; then
        container="docker"
    elif command -v podman >/dev/null 2>&1; then
        container="podman"
    fi
fi

if [ -z "$container" ]; then
    if ! command -v "${SWIFT_BIN:-swift}" >/dev/null 2>&1; then
        {
            echo "Fehler: weder Docker/Podman noch ein lokales Swift gefunden."
            echo "Optionen:"
            echo "  • Container-Laufzeit starten (Docker/Podman), oder"
            echo "  • Swift lokal installieren und SWIFT_IMAGE=local setzen."
            echo "In GitHub Actions ist beides vorhanden – dort ist dieser Weg der Standard."
        } >&2
        exit 127
    fi
    echo "→ Ohne Container (lokales Swift): $*"
    rc=0
    CI_SUMMARY_FILE="$summary" "$@" || rc=$?
    append_summary
    exit "$rc"
fi

echo "→ Container $image ($container): $*"
rc=0
"$container" run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e GITHUB_ACTIONS="${GITHUB_ACTIONS:-}" \
    -e CI_SUMMARY_FILE="/src/$summary" \
    -v "$PWD:/src" \
    -w /src \
    "$image" "$@" || rc=$?

append_summary
exit "$rc"
