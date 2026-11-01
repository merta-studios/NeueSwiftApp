#!/usr/bin/env bash
#
# ci/detect-scheme.sh – ermittelt das Xcode-Scheme eines Swift-Pakets.
#
#   ci/detect-scheme.sh NeueSwiftApp.swiftpm
#
# Reihenfolge:
#   1. APP_SCHEME (Repository-Variable) – bewusste Vorgabe gewinnt immer.
#   2. Scheme mit dem Namen des Pakets (z. B. "NeueSwiftApp").
#   3. "NeueSwiftApp.swiftpm".
#   4. Erstes Scheme, das nicht nur ein Target ist.
#   5. Erstes Scheme überhaupt.
#
# Ausgabe: der Scheme-Name auf stdout. Fehlerhaftes Verhalten endet mit einem
# Fehler statt mit einer leeren Ausgabe – ein leerer Scheme-Name würde beim
# Build zu einem unklaren Fehler führen.

set -uo pipefail

package_dir="${1:-NeueSwiftApp.swiftpm}"

err() { printf '%s\n' "$*" >&2; }

if [ ! -d "$package_dir" ]; then
    err "Paketordner '$package_dir' fehlt."
    exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
    err "xcodebuild fehlt – dieses Skript läuft nur auf macOS mit Xcode."
    exit 1
fi

package_name="$(basename "$package_dir")"
package_name="${package_name%.swiftpm}"

listing="$(cd "$package_dir" && xcodebuild -list -json 2>&1)"

if [ -n "${APP_SCHEME:-}" ]; then
    if printf '%s' "$listing" | grep -qF "\"$APP_SCHEME\""; then
        printf '%s\n' "$APP_SCHEME"
        exit 0
    fi
    err "APP_SCHEME='$APP_SCHEME' kommt in 'xcodebuild -list' nicht vor."
    err "Gefundene Schemes werden unten ausgegeben."
fi

scheme="$(printf '%s' "$listing" | python3 -c '
import json
import sys

package = sys.argv[1]
raw = sys.stdin.read()
start = raw.find("{")
if start < 0:
    raise SystemExit(0)
try:
    listing = json.loads(raw[start:])
except ValueError:
    raise SystemExit(0)

schemes = []
targets = []
for container in ("workspace", "project", "package"):
    section = listing.get(container) or {}
    schemes.extend(section.get("schemes") or [])
    targets.extend(section.get("targets") or [])

# Doppelte Namen nur einmal behalten, Reihenfolge erhalten.
schemes = list(dict.fromkeys(schemes))
targets = list(dict.fromkeys(targets))

for preferred in (package, package + ".swiftpm"):
    if preferred in schemes:
        print(preferred)
        raise SystemExit(0)

for scheme in schemes:
    if scheme not in targets:
        print(scheme)
        raise SystemExit(0)

if schemes:
    print(schemes[0])
' "$package_name")"

if [ -z "$scheme" ]; then
    err "Kein Scheme ermittelbar. Ausgabe von 'xcodebuild -list -json':"
    printf '%s\n' "$listing" >&2
    exit 1
fi

printf '%s\n' "$scheme"
