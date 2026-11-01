#!/usr/bin/env bash
#
# ci/lib.sh – gemeinsame Helfer für die CI-Skripte.
#
# Wird geladen mit:
#   . "$(dirname "$0")/lib.sh"
#
# Enthält nur Ausgabehilfen: GitHub-Annotationen (erscheinen direkt an der
# betroffenen Zeile im Pull Request) und die Zerlegung von Compilerausgaben.
# Damit sind Fehler auch dann sichtbar, wenn das vollständige Schritt-Protokoll
# nicht abrufbar ist.

# shellcheck shell=bash

# Anzahl der bisher ausgegebenen Annotationen (GitHub zeigt nur eine begrenzte
# Zahl an; der Rest bleibt im Protokoll).
CI_ANNOTATION_COUNT="${CI_ANNOTATION_COUNT:-0}"
CI_ANNOTATION_LIMIT="${CI_ANNOTATION_LIMIT:-15}"

ci_escape_prop() { # Eigenschaftswert (Datei, Zeile, Spalte) maskieren
    local value="$1"
    value="${value//%/%25}"
    value="${value//:/%3A}"
    value="${value//,/%2C}"
    printf '%s' "$value"
}

ci_escape_data() { # Meldungstext maskieren (Zeilenumbrüche erlaubt)
    local value="$1"
    value="${value//%/%25}"
    value="${value//$'\r'/%0D}"
    value="${value//$'\n'/%0A}"
    printf '%s' "$value"
}

ci_annotate() { # ci_annotate <error|warning|notice> <datei> <zeile> <spalte> <text>
    [ "${GITHUB_ACTIONS:-}" = "true" ] || return 0
    local level="$1" file="$2" line="$3" column="$4" message="$5"
    CI_ANNOTATION_COUNT=$((CI_ANNOTATION_COUNT + 1))
    if [ "$CI_ANNOTATION_COUNT" -gt "$CI_ANNOTATION_LIMIT" ]; then
        if [ "$CI_ANNOTATION_COUNT" -eq $((CI_ANNOTATION_LIMIT + 1)) ]; then
            printf '::notice::Weitere Meldungen stehen im Protokoll dieses Schritts.\n'
        fi
        return 0
    fi
    printf '::%s file=%s,line=%s,col=%s,title=%s::%s\n' \
        "$level" \
        "$(ci_escape_prop "$file")" \
        "$(ci_escape_prop "$line")" \
        "$(ci_escape_prop "$column")" \
        "$(ci_escape_prop "$(basename "$file")")" \
        "$(ci_escape_data "$message")"
}

# Zerlegt die Ausgabe von swiftc/swift-format in Einzelmeldungen und gibt sie
# zusätzlich als Annotation aus. Format:
#   <datei>:<zeile>:<spalte>: <error|warning|note>: <meldung>
ci_report_swift_output() { # ci_report_swift_output <ausgabe> [standardstufe]
    local output="$1" default_level="${2:-error}"
    local line file lineno column level message
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [[ "$line" =~ ^(.*\.swift):([0-9]+):([0-9]+):\ (error|warning|note):\ (.*)$ ]]; then
            file="${BASH_REMATCH[1]}"
            lineno="${BASH_REMATCH[2]}"
            column="${BASH_REMATCH[3]}"
            level="${BASH_REMATCH[4]}"
            message="${BASH_REMATCH[5]}"
            [ "$level" = "note" ] && level="notice"
            printf '%s\n' "$line"
            ci_annotate "$level" "$file" "$lineno" "$column" "$message"
        else
            printf '%s\n' "$line"
            # Zeilen ohne Positionsangabe trotzdem sichtbar machen.
            ci_annotate "$default_level" "$(basename "${0}")" 1 1 "$line"
        fi
    done <<<"$output"
}
