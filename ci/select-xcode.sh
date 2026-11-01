#!/usr/bin/env bash
#
# ci/select-xcode.sh – wählt auf einem macOS-Runner die Xcode-Version aus.
#
#   XCODE_APP="/Applications/Xcode_26.6.app" ci/select-xcode.sh
#   XCODE_APP="26.6" ci/select-xcode.sh      # Version statt Pfad
#   ci/select-xcode.sh                        # neueste stabile Version
#
# Ohne Vorgabe wird die höchste installierte *stabile* Xcode-Version genommen
# (Beta- und Release-Candidate-Builds nur, wenn sonst nichts vorhanden ist).
# Die Auswahl wird im Schritt-Protokoll und in der Job-Zusammenfassung
# festgehalten, damit nachvollziehbar bleibt, womit gebaut wurde.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

if ! command -v xcodebuild >/dev/null 2>&1; then
    err "xcodebuild fehlt – dieses Skript läuft nur auf macOS mit Xcode."
    exit 1
fi

version_of() { # version_of <app-pfad>
    DEVELOPER_DIR="$1/Contents/Developer" xcodebuild -version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

is_prerelease() { # is_prerelease <app-pfad> <version>
    case "$1" in *[Bb]eta* | *[Rr]elease\ [Cc]andidate* | *RC*) return 0 ;; esac
    case "$2" in *[Bb]eta* | *RC*) return 0 ;; esac
    return 1
}

chosen=""
requested="${XCODE_APP:-}"

if [ -n "$requested" ]; then
    if [ -d "$requested" ] && [ -d "$requested/Contents/Developer" ]; then
        chosen="$requested"
    elif [ -d "/Applications/Xcode_${requested}.app" ]; then
        chosen="/Applications/Xcode_${requested}.app"
    elif [ -d "/Applications/Xcode.app" ] && [ "$(version_of /Applications/Xcode.app)" = "$requested" ]; then
        chosen="/Applications/Xcode.app"
    else
        err "XCODE_APP='$requested' passt auf kein installiertes Xcode."
        ls -d /Applications/Xcode*.app 2>/dev/null || true
        exit 1
    fi
    note "Xcode aus Repository-Variable XCODE_APP: $chosen"
else
    stable=""
    stable_version=""
    fallback=""
    fallback_version=""
    for app in /Applications/Xcode*.app; do
        [ -d "$app" ] || continue
        version="$(version_of "$app")"
        [ -n "$version" ] || continue
        if is_prerelease "$app" "$version"; then
            if [ -z "$fallback" ] || [ "$(printf '%s\n%s\n' "$fallback_version" "$version" | sort -V | tail -n 1)" = "$version" ]; then
                fallback="$app"
                fallback_version="$version"
            fi
        else
            if [ -z "$stable" ] || [ "$(printf '%s\n%s\n' "$stable_version" "$version" | sort -V | tail -n 1)" = "$version" ]; then
                stable="$app"
                stable_version="$version"
            fi
        fi
    done

    if [ -n "$stable" ]; then
        chosen="$stable"
        note "Neueste stabile Xcode-Version: $stable_version"
    elif [ -n "$fallback" ]; then
        chosen="$fallback"
        warn "Nur Vorabversionen gefunden – benutze $fallback_version"
    else
        err "Kein Xcode unter /Applications gefunden."
        exit 1
    fi
fi

log "Xcode auswählen"
if [ "$(id -u)" -eq 0 ]; then
    xcode-select -s "$chosen/Contents/Developer" || { err "xcode-select fehlgeschlagen."; exit 1; }
else
    sudo xcode-select -s "$chosen/Contents/Developer" || { err "xcode-select fehlgeschlagen."; exit 1; }
fi

ok "Verwende $chosen"
xcodebuild -version

ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || echo "unbekannt")"
sim_runtime="$(xcrun simctl list runtimes 2>/dev/null | grep -m 1 -E '^iOS' || echo "unbekannt")"
note "iOS-SDK (Simulator): $ios_sdk"
note "$sim_runtime"

xcode_line="$(xcodebuild -version 2>/dev/null | head -n 1)"
if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::notice title=macOS-Buildumgebung::%s | iOS-SDK %s | %s\n' \
        "$xcode_line" "$ios_sdk" "$sim_runtime"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
        echo "### macOS-Build-Umgebung"
        echo
        echo '```'
        xcodebuild -version
        echo "Xcode: $chosen"
        echo "iOS-SDK (Simulator): $ios_sdk"
        echo "$sim_runtime"
        echo '```'
    } >>"$GITHUB_STEP_SUMMARY"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
    echo "DEVELOPER_DIR=$chosen/Contents/Developer" >>"$GITHUB_ENV"
    echo "XCODE_APP_SELECTED=$chosen" >>"$GITHUB_ENV"
fi

exit 0
