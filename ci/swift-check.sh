#!/usr/bin/env bash
#
# ci/swift-check.sh – Syntax-Prüfung aller Swift-Dateien dieses Repos ohne
# Mac, Xcode und iOS-SDK. Läuft im Swift-Container (ci/run-swift.sh) oder lokal
# mit installiertem Swift.
#
#   ci/swift-check.sh parse     # jede .swift-Datei parsen (Standard)
#   ci/swift-check.sh files     # nur die gefundenen Dateien auflisten
#
# Warum nur parsen? SwiftUI/UIKit/PencilKit gibt es unter Linux nicht, ein
# vollständiger Typ-Check ist dort unmöglich. `swiftc -frontend -parse` löst
# keine Module auf und findet trotzdem jede Syntaxverletzung. Die echte
# Typ-Prüfung des iOS-Codes macht der macOS-Job mit dem iOS-SDK; die
# plattformunabhängige App-Logik prüft Tests/run-core-tests.sh mit echtem
# `swiftc -typecheck`.
#
# Es gibt bewusst keine Möglichkeit, Fehler „nur zu melden“: ein Syntaxfehler
# ist immer ein Fehlschlag, und null gefundene Dateien sind ebenfalls ein
# Fehlschlag (dann wurde nichts geprüft).
#
# Umgebungsvariablen:
#   SWIFTC         Compiler (Standard: swiftc)
#   CI_SUMMARY_FILE  Datei für die Schritt-Zusammenfassung (optional)
#
# Rückgabewert: 0 = alle Dateien syntaktisch in Ordnung, 1 = Fehler.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

SWIFTC="${SWIFTC:-swiftc}"
SUMMARY_FILE="${CI_SUMMARY_FILE:-}"
BATCH_SIZE=8
ERRORS=0
WARNINGS=0
CHECKED=0

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

summary_append() {
    [ -n "$SUMMARY_FILE" ] || return 0
    printf '%s\n' "$1" >>"$SUMMARY_FILE"
}

# GitHub-Annotationen: Zeilen erscheinen direkt an der betroffenen Code-Zeile.
escape_prop() {
    local value="$1"
    value="${value//%/%25}"
    value="${value//:/%3A}"
    value="${value//,/%2C}"
    printf '%s' "$value"
}

escape_data() {
    local value="$1"
    value="${value//%/%25}"
    value="${value//$'\r'/%0D}"
    value="${value//$'\n'/%0A}"
    printf '%s' "$value"
}

annotate() { # annotate <error|warning|notice> <datei> <zeile> <spalte> <text>
    [ "${GITHUB_ACTIONS:-}" = "true" ] || return 0
    printf '::%s file=%s,line=%s,col=%s::%s\n' \
        "$1" "$(escape_prop "$2")" "$(escape_prop "$3")" \
        "$(escape_prop "$4")" "$(escape_data "$5")"
}

# Compiler-Ausgabe in Einzelmeldungen zerlegen und ausgeben.
report_output() { # report_output <ausgabe>
    local line level file lineno column message
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [[ "$line" =~ ^(.*\.swift):([0-9]+):([0-9]+):\ (error|warning|note):\ (.*)$ ]]; then
            file="${BASH_REMATCH[1]}"
            lineno="${BASH_REMATCH[2]}"
            column="${BASH_REMATCH[3]}"
            level="${BASH_REMATCH[4]}"
            message="${BASH_REMATCH[5]}"
            case "$level" in
                error)
                    err "$file:$lineno:$column: $message"
                    ERRORS=$((ERRORS + 1))
                    ;;
                warning)
                    warn "$file:$lineno:$column: $message"
                    WARNINGS=$((WARNINGS + 1))
                    ;;
                *)
                    note "$file:$lineno:$column: $message"
                    ;;
            esac
            annotate "$level" "$file" "$lineno" "$column" "$message"
        else
            printf '%s\n' "$line"
        fi
    done <<<"$1"
}

source_files() {
    find . -name '*.swift' \
        -not -path './.build/*' \
        -not -path '*/.build/*' \
        -not -path './DerivedData/*' \
        -not -path '*/DerivedData/*' \
        -not -path '*/.swiftpm/configuration/*' \
        | sort
}

require_compiler() {
    if ! command -v "$SWIFTC" >/dev/null 2>&1; then
        echo "Swift-Compiler '$SWIFTC' nicht gefunden." >&2
        echo "Lokal: ci/run-swift.sh ci/swift-check.sh parse – oder SWIFTC setzen." >&2
        exit 127
    fi
}

run_parse() {
    log "Syntax-Prüfung: alle Swift-Dateien"
    local -a files=()
    mapfile -t files < <(source_files)
    local total="${#files[@]}"

    if [ "$total" -eq 0 ]; then
        err "Keine Swift-Datei gefunden – es wurde nichts geprüft."
        summary_append "- ❌ Syntax: keine Swift-Datei gefunden"
        return 1
    fi

    local compiler_version
    compiler_version="$("$SWIFTC" --version 2>&1 | head -n 1)"
    note "$total Dateien, Compiler: $compiler_version"

    local index=0 output file
    local -a block=()
    while [ "$index" -lt "$total" ]; do
        block=("${files[@]:index:BATCH_SIZE}")
        index=$((index + BATCH_SIZE))

        # Ein Block ist schnell geprüft; erst bei einem Fehler im Block wird
        # jede Datei einzeln geparst, damit die Meldung an der richtigen Datei
        # landet.
        if output=$("$SWIFTC" -frontend -parse "${block[@]}" 2>&1); then
            [ -n "$output" ] && report_output "$output"
            CHECKED=$((CHECKED + ${#block[@]}))
            continue
        fi

        for file in "${block[@]}"; do
            if output=$("$SWIFTC" -frontend -parse "$file" 2>&1); then
                [ -n "$output" ] && report_output "$output"
            else
                err "Syntaxfehler in $file"
                report_output "$output"
            fi
            CHECKED=$((CHECKED + 1))
        done
    done

    echo
    if [ "$ERRORS" -eq 0 ] && [ "$CHECKED" -eq "$total" ]; then
        ok "Alle $total Dateien sind syntaktisch in Ordnung."
        summary_append "- ✅ Syntax: $total Dateien geparst, keine Fehler"
        return 0
    fi

    if [ "$CHECKED" -ne "$total" ]; then
        err "Nur $CHECKED von $total Dateien wurden geprüft."
    fi
    err "$ERRORS Syntaxfehler in $CHECKED Dateien."
    summary_append "- ❌ Syntax: $ERRORS Fehler in $CHECKED von $total Dateien"
    return 1
}

require_compiler
log "Swift-Code-Prüfung (nur Syntax; Typen prüfen core-tests und der macOS-Build)"
summary_append "### Swift-Code-Prüfung"
summary_append ""

status=0
case "${1:-parse}" in
    parse) run_parse || status=1 ;;
    files) source_files ;;
    -h | --help)
        sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unbekannter Modus: $1 (erwartet: parse, files)" >&2
        exit 2
        ;;
esac

echo
note "Fehler: $ERRORS, Warnungen: $WARNINGS"
exit "$status"
